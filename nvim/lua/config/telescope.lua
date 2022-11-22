local telescope = require("telescope")
local telescope_actions = require("telescope.actions")
local builtin = require("telescope.builtin")
local themes = require("telescope.themes")
local trouble = require("trouble.providers.telescope")

-- TODO: Add a way to open file explorer with current file selected
-- alternatively, add a keymap to find current file in file explorer.

local function setnormal()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end

local function setinsert()
  vim.cmd([[startinsert]])
end

local function noop()
  -- print("BOOP!")
end

-- A 'quick' picker that starts in insert mode and expects the user to accept the current match with <CR>
local function quick_picker(opts)
  return vim.tbl_deep_extend("force", {
    initial_mode = "insert",
    mappings = {
      i = {
        ["<esc>"] = telescope_actions.close,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble.smart_open_with_trouble,
        ["<C-q>"] = false,
        ["<M-q>"] = false,
      },
      n = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble.smart_open_with_trouble,
        ["<C-q>"] = false,
        ["<M-q>"] = false,
      },
    },
  }, opts or {})
end

-- A 'slow' picker that starts in normal mode and expects the user to use / to search
-- and <CR> to 'accept' the search and go back to normal mode.
local function slow_picker(opts)
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
        ["<C-t>"] = trouble.open_with_trouble,
        ["<C-q>"] = false,
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
        ["<C-t>"] = trouble.open_with_trouble,
        ["<C-q>"] = false,
        ["<M-q>"] = false,
      },
    },
  }, opts or {})
end

telescope.setup({
  defaults = quick_picker(vim.tbl_deep_extend("force", themes.get_ivy(), {
    entry_prefix = "  ",
    prompt_prefix = "   ",
    selection_caret = "  ",
    color_devicons = true,
  })),
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
    ["ui-select"] = {
      themes.get_dropdown({}),
    },
    file_browser = slow_picker({
      hijack_netrw = true,
      path = "%:p:h",
      cwd_to_path = false,
      respect_gitignore = false,
    }),
  },
  pickers = {
    find_files = {
      hidden = true,
    },
    oldfiles = {
      -- TODO: something like only_project_root = true (doesn't actually exist)
      only_cwd = true,
      -- TODO: add mapping to toggle only_cwd
    },
    buffers = quick_picker({
      theme = "dropdown",
      ignore_current_buffer = false,
      sort_mru = true,
      sort_lastused = true,
      previewer = false,
      mappings = {
        i = {
          -- TODO: Fix case for deleting current buffer (doesn't delete)
          ["<C-d>"] = telescope_actions.delete_buffer,
        },
        n = {
          ["<C-d>"] = telescope_actions.delete_buffer,
        },
      },
    }),
    git_branches = slow_picker(),
    git_status = slow_picker(),
    git_stash = slow_picker(),
  },
})

telescope.load_extension("fzf")
telescope.load_extension("ui-select")
telescope.load_extension("file_browser")
telescope.load_extension("persisted")
telescope.load_extension("projects")

local function nvim_config_files()
  builtin.find_files({
    prompt_title = "Nvim Config Files",
    cwd = vim.env.NVIM_CONFIG_DIR,
  })
end

local function xdg_config_files()
  builtin.find_files({
    prompt_title = "Config Files",
    cwd = vim.env.XDG_CONFIG_HOME,
  })
end

local function xdg_config_grep()
  builtin.live_grep({
    prompt_title = "Search Config",
    search_dirs = { vim.env.XDG_CONFIG_HOME },
  })
end

require("keymap").normal.leader({
  p = { "<cmd>Telescope<CR>", "Telescope" },
  e = { "<cmd>Telescope file_browser<CR>", "File Explorer" },
  t = { "<cmd>Telescope buffers<CR>", "Buffers" },
  bb = { "<cmd>Telescope buffers<CR>", "Buffers" },
  f = { "<cmd>Telescope find_files<CR>", "Files" },
  r = { "<cmd>Telescope oldfiles<CR>", "Recent Files" },
  ["/"] = { "<cmd>Telescope current_buffer_fuzzy_find<CR>", "Text in file" },
  ["*"] = { "<cmd>Telescope grep_string<CR>", "Word under cursor" },

  s = {
    name = "Search",
    f = { "<cmd>Telescope find_files<CR>", "Files" },
    r = { "<cmd>Telescope oldfiles<CR>", "Recent File" },
    ["/"] = { "<cmd>Telescope current_buffer_fuzzy_find<CR>", "Text in file" },
    ["*"] = { "<cmd>Telescope grep_string<CR>", "Word under cursor" },
    t = { "<cmd>Telescope live_grep<CR>", "Text" },
    C = { "<cmd>Telescope colorscheme<CR>", "Colorschemes" },
    h = { "<cmd>Telescope help_tags<CR>", "Help" },
    m = { "<cmd>Telescope man_pages<CR>", "Manpages" },
    o = { "<cmd>Telescope vim_options<CR>", "Vim options" },
    H = { "<cmd>Telescope highlights<CR>", "Highlights" },
    k = { "<cmd>Telescope keymaps<CR>", "Keymaps" },
    c = { "<cmd>Telescope command_history<CR>", "Command history" },
    s = { "<cmd>Telescope lsp_document_symbols<CR>", "Document Symbols" },
    S = { "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", "Workspace Symbols" },
    q = { "<cmd>Telescope quickfix<CR>", "Quickfix" },
    j = { "<cmd>Telescope jumplist<CR>", "Jumplist" },
    e = {
      name = "Emoji",
      e = { "<cmd>lua require'telescope.builtin'.symbols({sources={'emoji'}})<CR>", "Emoji 😀" },
      g = { "<cmd>lua require'telescope.builtin'.symbols({sources={'gitmoji'}})<CR>", "Gitmoji 🚀" },
      a = {
        "<cmd>lua require'telescope.builtin'.symbols({sources={'kaomoji'}})<CR>",
        "Art (╯°□°）╯︵ ┻━┻",
      },
      m = { "<cmd>lua require'telescope.builtin'.symbols({sources={'math'}})<CR>", "Math Symbols ∑" },
    },
  },
  g = {
    name = "Git",
    f = { "<cmd>Telescope git_files<CR>", "Git files" },
    c = { "<cmd>Telescope git_commits<CR>", "Commits" },
    C = { "<cmd>Telescope git_bcommits<CR>", "Buffer Commits" },
    b = { "<cmd>Telescope git_branches<CR>", "Branches" },
    s = { "<cmd>Telescope git_status<CR>", "Status" },
    S = { "<cmd>Telescope git_stash<CR>", "Stash" },
  },
  c = {
    name = "Config",
    ["n"] = { nvim_config_files, "Neovim Config Files" },
    ["f"] = { xdg_config_files, "Find Config Files" },
    ["s"] = { xdg_config_grep, "Search Config Dir" },
  },
  -- TODO: implement something like lvim's info: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/info.lua
  -- TODO: implement something like lvim's log: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/which-key.lua#L211-L236
  -- TODO: implement something like lvim's peak:https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/which-key.lua#L173-L178
})
