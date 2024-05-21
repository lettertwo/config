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

local DEFAULTS = {
  layout = {
    bottom_pane = {
      height = 25,
      preview_cutoff = 120,
      prompt_position = "top",
    },
    center = {
      height = 0.4,
      preview_cutoff = 40,
      prompt_position = "top",
      width = 0.5,
    },
    cursor = {
      height = 0.9,
      preview_cutoff = 40,
      width = 0.8,
    },
    horizontal = {
      height = 0.9,
      preview_cutoff = 120,
      prompt_position = "bottom",
      width = 0.8,
    },
    vertical = {
      height = 0.9,
      preview_cutoff = 40,
      prompt_position = "bottom",
      width = 0.8,
    },
  },
  mappings = {
    i = {
      ["<esc>"] = telescope_actions.close,
      ["<C-j>"] = telescope_actions.move_selection_next,
      ["<C-k>"] = telescope_actions.move_selection_previous,
      ["<C-n>"] = telescope_actions.cycle_history_next,
      ["<C-p>"] = telescope_actions.cycle_history_prev,
      -- FIXME: These bindings only really work for file locations,
      -- so they shouldn't be enabled for every picker by default.
      -- The same goes for the other modes and pickers.
      ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
      ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
      ["<C-t>"] = trouble.smart_open_with_trouble,
      ["<C-e>"] = actions.open_in_file_explorer,
      ["<M-q>"] = false,
      ["<C-x>"] = false,
      ["<C-s>"] = telescope_actions.select_horizontal,
      ["<C-y>"] = actions.yank_to_clipboard,
      -- FIXME: Refinment doesn't work or doesn't make sense for every picker
      ["<BS>"] = actions.unrefine_or_default,
      ["<C-space>"] = actions.refine,
    },
    n = {
      ["<C-j>"] = telescope_actions.move_selection_next,
      ["<C-k>"] = telescope_actions.move_selection_previous,
      ["<C-n>"] = telescope_actions.cycle_history_next,
      ["<C-p>"] = telescope_actions.cycle_history_prev,
      ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
      ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
      ["<C-t>"] = trouble.smart_open_with_trouble,
      ["<C-e>"] = actions.open_in_file_explorer,
      ["<M-q>"] = false,
      ["<C-x>"] = false,
      ["<C-s>"] = telescope_actions.select_horizontal,
      ["<C-y>"] = actions.yank_to_clipboard,
      ["<BS>"] = actions.unrefine_or_default,
      ["<C-space>"] = actions.refine,
    },
  },
}

-- A 'quick' picker that starts in insert mode and expects the user to accept the current match with <CR>
function M.quick_picker(opts)
  return vim.tbl_deep_extend("force", DEFAULTS, {
    initial_mode = "insert",
  }, opts or {})
end

-- A 'slow' picker that starts in normal mode and expects the user to use / to search
-- and <CR> to 'accept' the search and go back to normal mode.
function M.slow_picker(opts)
  return vim.tbl_deep_extend("force", DEFAULTS, {
    initial_mode = "normal",
    attach_mappings = function(_, map)
      map("i", "<cr>", setnormal)
      map("n", "/", setinsert)
      map("n", "i", noop)
      map("n", "a", noop)
      map("n", "I", noop)
      map("n", "A", noop)
      map("n", "R", noop)
      return true
    end,
  }, opts or {})
end

return M
