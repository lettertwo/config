---@module "snacks"
---@type table<string, snacks.picker.Action.spec>
local refine_actions = {}

--- @param next_picker snacks.Picker
--- @param prev_picker snacks.Picker
local function refined_statuscolumn(next_picker, prev_picker)
  ---@param self snacks.picker.input
  return function(self)
    local parts = {} ---@type string[]

    local function add(str, hl)
      if str then
        parts[#parts + 1] = ("%%#%s#%s%%*"):format(hl, str:gsub("%%", "%%"))
      end
    end

    local refinements = {}
    local prev = next_picker
    while prev and prev.refined do
      refinements[#refinements + 1] = prev.refined
      prev = prev.refined
    end

    for i = #refinements, 1, -1 do
      local refined = refinements[i]
      if refined then
        local title = refined.title
        if #title > 20 then
          title = require("snacks.picker.util").truncate(title, 20)
        end
        add(title, "SnacksPickerTitle")
        add(prev_picker.opts.prompt or " ", "SnacksPickerPrompt")

        local prev_input = refined.input
        if prev_input ~= "" then
          if #prev_input > 20 then
            prev_input = require("snacks.picker.util").truncate(prev_input, 20)
          end
          add(prev_input, "SnacksPickerInputSearch")
          add(prev_picker.opts.prompt or " ", "SnacksPickerPrompt")
        end
      end
    end

    return table.concat(parts, " ")
  end
end

--- @param picker snacks.Picker
--- @param source? string
--- @param opts? snacks.picker.Config
local function push_refinement(picker, source, opts)
  local prev_picker = {
    opts = picker.opts,
    selected = picker.selected,
    cursor = picker.list.cursor,
    filter = picker.input.filter,
    topline = picker.list.top,
    input = picker.input:get(),
    title = picker.title,
    refined = picker.refined,
  }

  if source then
    for _, p in ipairs(Snacks.picker.get({ source = source })) do
      p:close()
    end
  end

  local new_opts = vim.tbl_deep_extend("force", opts or picker.opts, {
    on_open = function()
      picker:close()
    end,
  })

  if source == nil then
    new_opts.finder = nil
    new_opts.multi = nil
    new_opts.source = nil
    new_opts.matcher.sort_empty = false
    new_opts.items = picker:items()
  end

  local new_picker = source and Snacks.picker(source, new_opts) or Snacks.picker(new_opts)
  new_picker.opts.refined = true
  new_picker.refined = prev_picker
  new_picker.input.statuscolumn = refined_statuscolumn(new_picker, picker)
end

--- @param picker snacks.Picker
--- @param source? string
--- @param opts? snacks.picker.Config
local function replace_refinement(picker, source, opts)
  local prev_picker
  if picker.refined then
    prev_picker = {
      opts = picker.refined.opts,
      selected = picker.refined.selected,
      cursor = picker.refined.list.cursor,
      filter = picker.refined.input.filter,
      topline = picker.refined.list.top,
      input = picker.refined.input:get(),
      title = picker.refined.title,
      refined = picker.refined.refined,
    }
  end

  if source then
    for _, p in ipairs(Snacks.picker.get({ source = source })) do
      p:close()
    end
  end

  local new_opts = vim.tbl_deep_extend("force", opts or (prev_picker and prev_picker.opts or {}), {
    on_open = function()
      picker:close()
    end,
  })

  if source == nil then
    new_opts.finder = nil
    new_opts.multi = nil
    new_opts.source = nil
    new_opts.matcher.sort_empty = false
    new_opts.items = picker:items()
  end

  local new_picker = source and Snacks.picker(source, new_opts) or Snacks.picker(new_opts)

  if prev_picker then
    new_picker.opts.refined = true
    new_picker.refined = prev_picker
    new_picker.input.statuscolumn = refined_statuscolumn(new_picker, picker)
  end
end

--- @param picker snacks.Picker
local function pop_refinement(picker)
  if picker.refined then
    local last = picker.refined
    local last_opts = vim.tbl_deep_extend("force", last.opts, {})
    last_opts.pattern = last.filter.pattern
    last_opts.search = last.filter.search
    last_opts.on_open = function()
      picker:close()
    end

    local last_picker = picker.new(last_opts)
    last_picker.opts.refined = last.refined ~= nil
    last_picker.refined = last.refined
    last_picker.statuscolumn = refined_statuscolumn(last_picker, picker)
  else
    Snacks.notify.warn("No previous picker to refine", { title = picker.title })
  end
end

-- function refine.grep_items(picker)
--   local util = require("snacks.picker.util")
--   local is_insert_mode = vim.fn.mode():sub(1, 1) == "i"
--
--   local paths = vim
--     .iter(picker:iter())
--     :map(util.path)
--     :filter(function(path)
--       return path ~= nil
--     end)
--     :map(vim.fs.normalize)
--     :filter(function(path)
--       local filetype = vim.filetype.match({ filename = path })
--       return filetype and filetype ~= "binary" or false
--     end)
--     :totable()
--
--   if #paths > 0 then
--     picker:close()
--     Snacks.picker.grep({ dirs = paths })
--     -- HACK: Insert mode is stopped when the new picker opens.
--     -- So, if we _were_ in insert mode before,
--     -- re-enter insert mode after the new picker is opened.
--     if is_insert_mode then
--       vim.schedule(function()
--         vim.cmd.startinsert()
--       end)
--     end
--   else
--     Snacks.notify.warn("`" .. picker.title .. "` items do not support grep")
--   end
-- end

-- function refine.grep_items_or_toggle_live(picker)
--   if not picker.opts.supports_live then
--     return refine.grep_items(picker)
--   end
--
--   picker.opts.live = not picker.opts.live
--   picker.input:set()
--   picker.input:update()
-- end

---@module "snacks"
---@param picker snacks.Picker
-- function refine.grep_items_or_toggle_live_or_refine(picker)
--   local input = picker.input:get()
--   local is_insert_mode = vim.fn.mode():sub(1, 1) == "i"
--
--   if not input or input == "" then
--     return refine.grep_items_or_toggle_live(picker)
--   else
--     push_refinement(picker)
--
--     -- HACK: Insert mode is stopped when the new picker opens.
--     -- So, if we _were_ in insert mode before,
--     -- re-enter insert mode after the new picker is opened.
--     if is_insert_mode then
--       vim.schedule(function()
--         vim.cmd.startinsert()
--       end)
--     end
--   end
-- end

function refine_actions.grep_in_dir(picker, item)
  local ok, dir = pcall(Snacks.picker.util.dir, item)
  if item and ok and dir then
    push_refinement(picker, "grep", { cwd = dir })
  else
    Snacks.notify.warn("No directory to grep", { title = picker.title })
  end
end

function refine_actions.files_in_dir(picker, item)
  local ok, dir = pcall(Snacks.picker.util.dir, item)
  if item and ok and dir then
    push_refinement(picker, "files", { cwd = dir })
  else
    Snacks.notify.warn("No directory to open", { title = picker.title })
  end
end

function refine_actions.refine_or_cycle_picker(picker)
  local input = picker.input:get()

  if not input or input == "" then
    return refine_actions.cycle_picker(picker, item)
  else
    push_refinement(picker)
  end
end

function refine_actions.cycle_picker(picker)
  -- TODO: Cycle through initial picker, grep cwd picker, and files cwd picker
  -- Note: replace the refinement with the next picker
  local next_source = picker.opts.source == "grep" and "files" or "grep"
  local cwd = picker.opts.cwd
  replace_refinement(picker, next_source, { cwd = cwd })
end

function refine_actions.delete_char_or_pop_refine(picker)
  local input = picker.input:get()
  -- local is_insert_mode = vim.fn.mode():sub(1, 1) == "i"

  if (not input or input == "") and picker.refined then
    pop_refinement(picker)

    -- HACK: Insert mode is stopped when the new picker opens.
    -- So, if we _were_ in insert mode before,
    -- re-enter insert mode after the new picker is opened.
    -- if is_insert_mode then
    --   vim.schedule(function()
    --     vim.cmd.startinsert()
    --   end)
    -- end
  else
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "n", true)
  end
end

return refine_actions
