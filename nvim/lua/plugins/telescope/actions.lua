local action_state = require("telescope.actions.state")
local from_entry = require("telescope.from_entry")
local telescope_actions = require("telescope.actions")
local transform_mod = require("telescope.actions.mt").transform_mod

local entry_to_qf = function(entry)
  local text = entry.text

  if not text then
    if type(entry.value) == "table" then
      text = entry.value.text
    else
      text = entry.value
    end
  end

  return {
    bufnr = entry.bufnr,
    filename = from_entry.path(entry, false, false),
    lnum = vim.F.if_nil(entry.lnum, 1),
    col = vim.F.if_nil(entry.col, 1),
    text = text,
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

return transform_mod({
  send_to_quickfix = function(prompt_bufnr)
    send_to_qf_or_loclist(prompt_bufnr)
  end,
  send_to_loclist = function(prompt_bufnr)
    send_to_qf_or_loclist(prompt_bufnr, "loclist")
  end,
  open_quickfix = function()
    if vim.fn.exists(":TroubleToggle") then
      vim.cmd([[TroubleToggle quickfix]])
    else
      vim.cmd([[copen]])
    end
  end,
  open_loclist = function()
    if vim.fn.exists(":TroubleToggle") then
      vim.cmd([[TroubleToggle loclist]])
    else
      vim.cmd([[lopen]])
    end
  end,
  delete_buffer = function(prompt_bufnr)
    local current_picker = action_state.get_current_picker(prompt_bufnr)
    current_picker:delete_selection(function(selection)
      local force = vim.api.nvim_buf_get_option(selection.bufnr, "buftype") == "terminal"
      local bufremove_ok, bufremove = pcall(require, "mini.bufremove")
      if bufremove_ok and bufremove then
        local ok = pcall(bufremove.delete, selection.bufnr, force)
        return ok
      else
        local ok = pcall(vim.api.nvim_buf_delete, selection.bufnr, { force = force })
        return ok
      end
    end)
  end,
  open_in_diffview = function(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    telescope_actions.close(prompt_bufnr)
    vim.cmd(("DiffviewOpen %s"):format(entry.value))
  end,
})
