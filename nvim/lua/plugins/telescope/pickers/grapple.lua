local themes = require("telescope.themes")

local finders = require("telescope.finders")
local utils = require("telescope.utils")
local entry_display = require("telescope.pickers.entry_display")
local strings = require("plenary.strings")

local M = {}

---@class GrappleOptions
---@field sort_lastused boolean
---@field ignore_current boolean
---@field sort_mru boolean
---@field sort_tags ?function
---@field select_current boolean

---@param opts? GrappleOptions
function M.grapple(opts)
  opts = opts or { sort_mru = false, ignore_current = true, sort_lastused = false }
  local Grapple = require("grapple")

  local function get_tags()
    local tags, err = Grapple.tags()
    if not tags then
      ---@diagnostic disable-next-line: param-type-mismatch
      return vim.notify(err, vim.log.levels.ERROR)
    end

    -- TODO: mru
    if opts.sort_mru then
      table.sort(tags, function(a, b)
        return vim.fn.getbufinfo(vim.fn.bufnr(a.path))[1].lastused > vim.fn.getbufinfo(vim.fn.bufnr(b.path))[1].lastused
      end)
    end

    if type(opts.sort_tags) == "function" then
      table.sort(tags, opts.sort_tags)
    end

    local results = {}
    local default_selection_idx = 1
    for i, tag in ipairs(tags) do
      local bufnr = vim.fn.bufnr(tag.path)
      local flag = bufnr == vim.fn.bufnr("") and "%" or (bufnr == vim.fn.bufnr("#") and "#" or " ")

      if opts.sort_lastused and not opts.ignore_current and flag == "#" then
        default_selection_idx = 2
      end

      ---@class grapple.telescope.result
      local result = {
        i,
        tag.path,
        tag.cursor and tag.cursor[1] or nil,
        tag.cursor and tag.cursor[2] or nil,

        bufnr = bufnr,
        flag = flag,
        info = vim.fn.getbufinfo(bufnr)[1],
      }

      if opts.sort_lastused and (flag == "#" or flag == "%") then
        local idx = ((results[1] ~= nil and results[1].flag == "%") and 2 or 1)
        table.insert(results, idx, result)
      else
        if opts.select_current and flag == "%" then
          default_selection_idx = bufnr
        end
        table.insert(results, result)
      end
    end
    return results, default_selection_idx
  end

  local disable_devicons = opts.disable_devicons

  local icon_width = 0
  if not disable_devicons then
    local icon, _ = utils.get_devicons("fname", disable_devicons)
    icon_width = strings.strdisplaywidth(icon)
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 1 },
      { width = icon_width },
      { remaining = true },
      { remaining = true },
    },
  })

  local function make_display(result)
    local path = utils.transform_path({}, result.filename)
    local basename = require("util").title_path(path)
    local dir_path = path.sub(path, 1, #path - #basename)
    local icon, hl_group = utils.get_devicons(result.filename, false)

    return displayer({
      { result.value[1], "TelescopeResultsNumber" },
      { icon, hl_group },
      basename,
      { dir_path, "TelescopePreviewDirectory" },
    })
  end

  local function make_entry(result)
    local filename = result[2]
    local lnum = result[3]

    return {
      value = result,
      ordinal = filename,
      display = make_display,
      bufnr = result.bufnr,
      filename = filename,
      lnum = lnum,
    }
  end

  local function delete_tag(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local selection = action_state.get_selected_entry()

    Grapple.untag({ path = selection.filename })

    local current_picker = action_state.get_current_picker(prompt_bufnr)
    current_picker:refresh(
      finders.new_table({
        results = get_tags(),
        entry_maker = make_entry,
      }),
      { reset_prompt = true }
    )
  end

  local tags, default_selection_idx = get_tags()

  require("telescope.pickers")
    .new(
      require("plugins.telescope.pickers").slow_picker(themes.get_dropdown({
        prompt_title = "Grapple Tags",
        preview_title = "",
        finder = finders.new_table({
          results = tags,
          entry_maker = make_entry,
        }),
        sorter = require("telescope.config").values.generic_sorter({}),
        previewer = require("telescope.config").values.grep_previewer({}),
        default_selection_index = default_selection_idx,
        attach_mappings = function(_, map)
          map("i", "<c-x>", delete_tag)
          map("n", "<c-x>", delete_tag)
          return true
        end,
      })),
      {}
    )
    :find()
end

return M
