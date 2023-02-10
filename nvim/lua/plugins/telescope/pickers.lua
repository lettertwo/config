local telescope_actions = require("telescope.actions")
local trouble = require("trouble.providers.telescope")
local actions = require("plugins.telescope.actions")

local function setnormal()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end

local function setinsert()
  vim.cmd([[startinsert]])
end

local function noop()
  -- print("BOOP!")
end

local M = {}

-- A 'quick' picker that starts in insert mode and expects the user to accept the current match with <CR>
function M.quick_picker(opts)
  return vim.tbl_deep_extend("force", {
    initial_mode = "insert",
    mappings = {
      i = {
        ["<esc>"] = telescope_actions.close,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
        ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
        ["<C-t>"] = trouble.smart_open_with_trouble,
        ["<M-q>"] = false,
      },
      n = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
        ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
        ["<C-t>"] = trouble.smart_open_with_trouble,
        ["<M-q>"] = false,
      },
    },
  }, opts or {})
end

-- A 'slow' picker that starts in normal mode and expects the user to use / to search
-- and <CR> to 'accept' the search and go back to normal mode.
function M.slow_picker(opts)
  return vim.tbl_deep_extend("force", {
    initial_mode = "normal",
    mappings = {
      i = {
        ["<cr>"] = setnormal,
        ["<esc>"] = telescope_actions.close,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
        ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
        ["<C-t>"] = trouble.open_with_trouble,
        ["<M-q>"] = false,
      },
      n = {
        ["/"] = setinsert,
        i = noop,
        a = noop,
        I = noop,
        A = noop,
        R = noop,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
        ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
        ["<C-t>"] = trouble.open_with_trouble,
        ["<M-q>"] = false,
      },
    },
  }, opts or {})
end

return M
