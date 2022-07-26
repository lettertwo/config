local telescope = require('telescope')
local telescope_actions = require("telescope.actions")
local builtin = require("telescope.builtin")
local themes = require("telescope.themes")
local _, trouble = pcall(require, "trouble.providers.telescope")

telescope.setup({
  defaults = vim.tbl_deep_extend("force", themes.get_ivy(), {
    prompt_prefix = " ",
    selection_caret = " ",
    entry_prefix = "  ",
    path_display = { "smart" },
    file_ignore_patterns = { ".git/", "node_modules" },
    mappings = {
      i = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-q>"] = telescope_actions.smart_send_to_qflist + telescope_actions.open_qflist,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble and trouble.open_with_trouble or nil,
      },
      n = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-q>"] = telescope_actions.smart_send_to_qflist + telescope_actions.open_qflist,
        ["<C-t>"] = trouble and trouble.open_with_trouble or nil,
      },
    }
  }),
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
    ['ui-select'] = {
      themes.get_dropdown({}),
    },
  },
  pickers = {
    find_files = {
      hidden = true,
    },
    buffers = {
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
    },
  },
})

telescope.load_extension 'fzf'
telescope.load_extension 'ui-select'
telescope.load_extension 'file_browser'

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
  k = { "<cmd>Telescope keymaps<CR>", "Keymaps" },
  e = { "<cmd>Telescope file_browser path=%:p:h respect_gitignore=false<CR>", "File Explorer" },
  t = { "<cmd>Telescope buffers<CR>", "Buffers" },
  bb = { "<cmd>Telescope buffers<CR>", "Buffers" },
  f = { "<cmd>Telescope find_files<CR>", "Files" },
  r = { "<cmd>Telescope oldfiles<CR>", "Recent File" },
  s = {
    name = "Search",
    f = { "<cmd>Telescope find_files<CR>", "Files" },
    r = { "<cmd>Telescope oldfiles<CR>", "Recent File" },
    ["/"] = { "<cmd>Telescope current_buffer_fuzzy_find<CR>", "Search file" },
    ["*"] = { "<cmd>Telescope grep_string<CR>", "Word under cursor" },
    ["a"] = { "<cmd>Telescope live_grep<CR>", "Grep files" },
    C = { "<cmd>Telescope colorscheme<CR>", "Colorschemes" },
    h = { "<cmd>Telescope help_tags<CR>", "Help" },
    m = { "<cmd>Telescope man_pages<CR>", "Manpages" },
    o = { "<cmd>Telescope vim_options<CR>", "Vim options" },
    H = { "<cmd>Telescope highlights<CR>", "Highlights" },
    c = { "<cmd>Telescope command_history<CR>", "Command history" },
    S = { "<cmd>Telescope search_history<CR>", "Search history" },
    q = { "<cmd>Telescope quickfix<CR>", "Quickfix" },
    j = { "<cmd>Telescope jumplist<CR>", "Jumplist" },
    g = {
      name = "Git",
      f = { "<cmd>Telescope git_files<CR>", "Git files" },
      c = { "<cmd>Telescope git_commits<CR>", "Commits" },
      b = { "<cmd>Telescope git_bcommits<CR>", "Buffer Commits" },
      B = { "<cmd>Telescope git_branches<CR>", "Branches" },
      s = { "<cmd>Telescope git_status<CR>", "Status" },
      S = { "<cmd>Telescope git_stash<CR>", "Stash" },
    },
    s = {
      name = "Symbols",
      e = { "<cmd>lua require'telescope.builtin'.symbols({sources={'emoji'}})<CR>", "Emoji 😀" },
      g = { "<cmd>lua require'telescope.builtin'.symbols({sources={'gitmoji'}})<CR>", "Gitmoji 🚀" },
      a = { "<cmd>lua require'telescope.builtin'.symbols({sources={'kaomoji'}})<CR>", "Art (╯°□°）╯︵ ┻━┻" },
      m = { "<cmd>lua require'telescope.builtin'.symbols({sources={'math'}})<CR>", "Math Symbols ∑" },
    },
  },
  c = {
    name = "Config",
    ["n"] = { nvim_config_files, "Neovim Config Files" },
    ["f"] = { xdg_config_files, "Find Config Files" },
    ["s"] = { xdg_config_grep, "Search Config Dir" },
  },
})
