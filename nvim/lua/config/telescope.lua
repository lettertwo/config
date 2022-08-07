local telescope = require("telescope")
local telescope_actions = require("telescope.actions")
local builtin = require("telescope.builtin")
local themes = require("telescope.themes")
local utils = require("telescope.utils")
local Path = require("plenary.path")
local trouble = require("trouble.providers.telescope")

local function normalized(_, path)
  local transformed_path = Path:new(path)
  if transformed_path:is_dir() then
    return transformed_path:normalize()
  else
    local tail = utils.path_tail(path)
    return string.format("%s (%s)", tail, transformed_path:normalize())
  end
end

telescope.setup({
  defaults = vim.tbl_deep_extend("force", themes.get_ivy(), {
    entry_prefix = "  ",
    prompt_prefix = "   ",
    selection_caret = "  ",
    color_devicons = true,
    path_display = normalized,
    file_ignore_patterns = { ".git/", "node_modules" },
    mappings = {
      i = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble.open_with_trouble,
        ["<C-q>"] = false,
        ["<M-q>"] = false,
      },
      n = {
        ["/"] = function()
          vim.cmd([[startinsert]])
        end,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble.open_with_trouble,
        ["<C-q>"] = false,
        ["<M-q>"] = false,
      },
    },
  }),
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
    file_browser = {
      initial_mode = "normal",
      hijack_netrw = true,
      path = "%:p:h",
      respect_gitignore = false,
    },
  },
  pickers = {
    find_files = {
      hidden = true,
    },
    buffers = {
      theme = "dropdown",
      initial_mode = "normal",
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
    git_branches = {
      initial_mode = "normal",
    },
    git_status = {
      initial_mode = "normal",
    },
    git_stash = {
      initial_mode = "normal",
    },
  },
})

telescope.load_extension("fzf")
telescope.load_extension("ui-select")
telescope.load_extension("file_browser")

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
  e = { "<cmd>Telescope file_browser<CR>", "File Explorer" },
  t = { "<cmd>Telescope buffers<CR>", "Buffers" },
  bb = { "<cmd>Telescope buffers<CR>", "Buffers" },
  f = { "<cmd>Telescope find_files<CR>", "Files" },
  r = { "<cmd>Telescope oldfiles<CR>", "Recent File" },
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
})
