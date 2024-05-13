local grapple_ok, Grapple = pcall(require, "grapple")
-- local smart_open_ok, smart_open = pcall(require, "plugins.telescope.smart_open")

if not grapple_ok then
  error("grapple is required for this extension")
end

-- if not smart_open_ok then
--   error("smart_open is required for this extension")
-- end

local themes = require("telescope.themes")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local utils = require("telescope.utils")
local strings = require("plenary.strings")
local make_entry = require("plugins.telescope.make_entry")

---@param opts SwitchOptions
local function get_tags(opts)
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

---@param prompt_bufnr number
---@param opts SwitchOptions
local function delete_tag(prompt_bufnr, opts)
  local action_state = require("telescope.actions.state")
  local selection = action_state.get_selected_entry()

  Grapple.untag({ path = selection.filename })

  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:refresh(
    finders.new_table({
      results = get_tags(opts),
      entry_maker = make_entry.gen_from_file_smart(opts),
    }),
    { reset_prompt = true }
  )
end

---@param opts? SwitchOptions
local function switch(opts)
  opts = require("telescope._extensions.switch.config").get(opts)

  local tags, default_selection_idx = get_tags(opts)

  -- TODO: implement some or all of these features of the builtin selector:
  -- [x] Selection (<cr>): select the tag under the cursor
  -- [x] Split (horizontal) (<c-s>): select the tag under the cursor (split)
  -- [x] Split (vertical) (|): select the tag under the cursor (vsplit)
  -- [ ] Quick select (default: 1-9): select the tag at a given index
  -- [ ] Deletion: delete a line to delete the tag
  -- [ ] Reordering: move a line to move a tag
  -- [ ] Renaming (R): rename the tag under the cursor
  -- [x] Quickfix (<c-q>): send all tags to the quickfix list (:h quickfix)
  -- [ ] Go up (-): navigate up to the scopes window
  -- [x] Help (?): open the help window
  -- [ ] Add smart_open to switch results.

  -- require("plugins.telescope.pickers").slow_picker(themes.get_dropdown({
  return pickers
    .new(opts, {
      prompt_title = "Switch to buffer",
      preview_title = "",
      finder = finders.new_table({
        results = tags,
        -- TODO: Reconcile this with the other extension entry makers (like git_jump)
        entry_maker = make_entry.gen_from_file_smart(opts),
      }),
      sorter = require("telescope.config").values.generic_sorter({}),
      previewer = require("telescope.config").values.grep_previewer({}),
      default_selection_index = default_selection_idx,
      attach_mappings = function(_, map)
        map("i", "<c-x>", delete_tag)
        map("n", "<c-x>", delete_tag)
        return true
      end,
    })
    :find()
end

return switch
