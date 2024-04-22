local action_state = require("telescope.actions.state")
local from_entry = require("telescope.from_entry")
local telescope_actions = require("telescope.actions")
local transform_mod = require("telescope.actions.mt").transform_mod
local Util = require("util")

local function text_from_entry(entry)
  local text = entry.text or entry.name

  if not text then
    if type(entry.value) == "table" then
      text = entry.value.text or entry.value.name
    elseif type(entry.value) == "string" then
      text = entry.value
    end
  end

  return text
end

local function entry_to_qf(entry)
  return {
    bufnr = entry.bufnr,
    filename = from_entry.path(entry, false, false),
    lnum = vim.F.if_nil(entry.lnum, 1),
    col = vim.F.if_nil(entry.col, 1),
    text = text_from_entry(entry),
  }
end

---@param prompt_bufnr number
---@param target "loclist" | "qf"? default is "qf"
local function send_to_qf_or_loclist(prompt_bufnr, target)
  local mode = " "

  local picker = action_state.get_current_picker(prompt_bufnr)
  local manager = picker.manager

  local selections = picker:get_multi_selection()

  local qf_entries = {}
  if vim.tbl_isempty(selections) then
    for entry in manager:iter() do
      table.insert(qf_entries, entry_to_qf(entry))
    end
  else
    for _, selection in ipairs(selections) do
      table.insert(qf_entries, entry_to_qf(selection))
    end
  end

  local prompt = picker:_get_prompt()
  telescope_actions.close(prompt_bufnr)

  if target == "loclist" then
    vim.fn.setloclist(picker.original_win_id, qf_entries, mode)
  else
    vim.fn.setqflist(qf_entries, mode)
    local qf_title = string.format([[%s (%s)]], picker.prompt_title, prompt)
    vim.fn.setqflist({}, "a", { title = qf_title })
  end
end

local Actions = {}

function Actions.send_to_quickfix(prompt_bufnr)
  send_to_qf_or_loclist(prompt_bufnr)
end

function Actions.send_to_loclist(prompt_bufnr)
  send_to_qf_or_loclist(prompt_bufnr, "loclist")
end

function Actions.open_quickfix()
  if vim.fn.exists(":TroubleToggle") then
    vim.cmd([[TroubleToggle quickfix]])
  else
    vim.cmd([[copen]])
  end
end

function Actions.open_loclist()
  if vim.fn.exists(":TroubleToggle") then
    vim.cmd([[TroubleToggle loclist]])
  else
    vim.cmd([[lopen]])
  end
end

function Actions.delete_buffer(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    return Util.delete_buffer(selection.bufnr)
  end)
end

function Actions.open_in_diffview(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  telescope_actions.close(prompt_bufnr)
  vim.cmd(("DiffviewOpen %s"):format(entry.value))
end

function Actions.open_in_file_explorer(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  telescope_actions.close(prompt_bufnr)

  local ok, MiniFiles = pcall(require, "mini.files")
  if ok and MiniFiles then
    local open_ok = pcall(MiniFiles.open, entry.filename or entry.path or entry.value)
    if not open_ok then
      vim.notify("Failed to open file in file explorer", vim.log.levels.ERROR)
    end
  end
end

function Actions.yank_to_clipboard(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local manager = picker.manager
  local selections = picker:get_multi_selection()
  local entries = {}

  if vim.tbl_isempty(selections) then
    for entry in manager:iter() do
      table.insert(entries, text_from_entry(entry))
    end
  else
    for _, selection in ipairs(selections) do
      table.insert(entries, text_from_entry(selection))
    end
  end

  vim.fn.setreg("+", entries)
  vim.notify(
    #entries > 1 and "Yanked " .. #entries .. " entries to clipboard" or "Yanked entry to clipboard",
    vim.log.levels.INFO
  )
end

function Actions.refine(prompt_bufnr)
  -- TODO: support refining on a multi selection
  -- TODO: support switching between file and grep search
  local conf = require("telescope.config").values
  local line = action_state.get_current_line()

  local picker = action_state.get_current_picker(prompt_bufnr)
  -- Opts to Picker:refresh:
  -- (parameter) opts: {
  --     multi: unknown,
  --     new_prefix: unknown,
  --     prefix_hl_group: unknown,
  --     reset_prompt: unknown,
  -- }
  local picker_opts = {
    multi = picker._multi,
    new_prefix = picker.prompt_prefix,
    prefix_hl_group = "TelescopePromptPrefix",
  }

  -- Push the current picker opts onto the refinements stack
  picker.refinements = picker.refinements or {}
  table.insert(picker.refinements, {
    finder = picker.finder,
    sorter = picker.sorter,
    title = picker.prompt_title,
    line = line,
    opts = picker_opts,
  })

  -- Update the prompt title
  picker.prompt_title = string.format("Refine (%s)", line)

  -- Opts to actions_generate.refine:
  -- (parameter) opts: {
  --     prompt_hl_group: unknown,
  --     prompt_prefix: unknown,
  --     prompt_title: unknown,
  --     prompt_to_prefix: unknown,
  --     push_history: unknown,
  --     reset_multi_selection: unknown,
  --     results_title: unknown,
  --     sorter: unknown,
  -- }
  require("telescope.actions.generate").refine(prompt_bufnr, {
    prompt_title = picker.prompt_title,
    prompt_to_prefix = true,
    sorter = conf.generic_sorter({}),
  })
end

function Actions.unrefine(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  if picker and picker.refinements and #picker.refinements > 0 then
    -- Pop the previous picker opts from the refinements stack
    local refinement = table.remove(picker.refinements)
    if refinement.sorter then
      picker.sorter:_destroy()
      picker.sorter = refinement.sorter
      picker.sorter:_init()
    end
    picker:refresh(refinement.finder, refinement.opts)
    picker:reset_prompt(refinement.line)
    picker.layout.prompt.border:change_title(refinement.title)
  end
end

function Actions.unrefine_or_default(prompt_bufnr)
  -- if the prompt is not empty, we should pass the key press through.
  if action_state.get_current_line() ~= "" then
    -- TODO: Figure out if we can retrieve the keypress to pass through.
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "n", true)
    return
  else
    return Actions.unrefine(prompt_bufnr)
  end
end

return transform_mod(Actions)
