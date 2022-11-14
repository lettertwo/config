local ok, packer = pcall(require, "packer")
if not ok then
  return
end

packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
})

local use = packer.use
packer.reset()

-- "always on" plugins; no setup necessary! --
use("wbthomason/packer.nvim") -- Packer can manage itself
use({ "lewis6991/impatient.nvim", config = [[ require("impatient") ]] }) -- Gotta go fast
use({
  "TaDaa/vimade", -- Fade inactive windows while preserving syntax highlights.
  setup = [[
    vim.g.vimade = {
    fadelevel = 0.7,
    enablesigns = 1,
    enablefocusfading = 1,
    enabletreesitter = 1,
  }
]],
})
-- Package manager for LSP, DAP, Linting, Formatting, etc.
use({ "williamboman/mason.nvim", config = [[ require("mason").setup() ]] })

-- Icons used by lots of other nvim plugins
use({ "kyazdani42/nvim-web-devicons", config = [[ require("nvim-web-devicons").setup({ default = true }) ]] })

-- Colorscheme --
use({ "~/.local/share/laserwave", requires = { "rktjmp/lush.nvim", "rktjmp/shipwright.nvim" } })

-- Lua plugin development --
use("nvim-lua/plenary.nvim") -- A common dependency in lua plugins. Also useful for testing plugins.
use("nanotee/luv-vimdocs")
use("milisims/nvim-luaref")
use("bfredl/nvim-luadev")
use("folke/neodev.nvim")

-- Occurrence operator --
use({ "~/.local/share/occurrency.nvim", config = [[ require("occurrency.dev").setup({}) ]] })

-- some assembly required --
use({ "goolord/alpha-nvim", config = [[ require("config.dashboard") ]] })
use({ "folke/which-key.nvim", config = [[ require("keymap") ]] })
use({ "numToStr/Comment.nvim", config = [[ require("config.comment") ]] })

-- Status bar, Tab bar, location --
use({
  "nvim-lualine/lualine.nvim",
  requires = { "SmiteshP/nvim-navic", "SmiteshP/nvim-gps" },
  after = { "nvim-lspconfig", "nvim-treesitter" },
  config = [[ require("config.lualine") ]],
})

-- UI for notifications, messages, cmdline, LSP status, etc. --
use({
  "folke/noice.nvim",
  requires = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
  config = [[ require("config.noice") ]],
})

-- Copilot (RIP my job)
use({
  "github/copilot.vim",
  setup = [[
  -- Accepting copilot suggestions is managed via nvim-cmp config.
  vim.g.copilot_no_tab_map = true -- Don't use default <Tab> binding.
  vim.g.copilot_assume_mapped = true -- A key is mapped (via cmp config) to accept copilot suggestions.
]],
})

-- Completion
use({
  "hrsh7th/nvim-cmp",
  requires = {
    { "hrsh7th/cmp-buffer" },
    { "hrsh7th/cmp-nvim-lsp" },
    { "hrsh7th/cmp-nvim-lsp-signature-help" },
    { "hrsh7th/cmp-path" },
    { "hrsh7th/cmp-nvim-lua" },
    { "lukas-reineke/cmp-under-comparator" },
    { "hrsh7th/cmp-nvim-lsp-document-symbol" },
    { "hrsh7th/cmp-calc" },
    { "hrsh7th/cmp-cmdline" },
    { "dmitmel/cmp-cmdline-history" },
    { "petertriho/cmp-git" },
    { "L3MON4D3/LuaSnip" },
  },
  config = [[require('config.cmp')]],
})

-- LSP
use({
  "neovim/nvim-lspconfig",
  requires = { "williamboman/mason-lspconfig.nvim", "folke/lua-dev.nvim", "simrat39/rust-tools.nvim" },
  after = { "mason.nvim", "cmp-nvim-lsp" },
  config = [[ require("config.lsp") ]],
})

-- Linting
use({
  "jose-elias-alvarez/null-ls.nvim",
  requires = { "jayp0521/mason-null-ls.nvim" },
  after = { "mason.nvim", "nvim-lspconfig" },
  config = [[ require("config.null-ls") ]],
})

-- Diagnostics
use({ "folke/trouble.nvim", after = "nvim-lspconfig", config = [[ require("config.diagnostics") ]] })

-- Treesitter and Highlighting
use({
  "nvim-treesitter/nvim-treesitter",
  requires = {
    "nvim-treesitter/nvim-treesitter-textobjects",
    "nvim-treesitter/nvim-treesitter-refactor",
    "nvim-treesitter/nvim-treesitter-context",
    "RRethy/nvim-treesitter-textsubjects",
    "RRethy/nvim-treesitter-endwise",
    "JoosepAlviste/nvim-ts-context-commentstring",
  },
  run = ":TSUpdate",
  config = [[ require("config.treesitter") ]],
})
-- Highlight colors
use({
  "norcalli/nvim-colorizer.lua",
  ft = { "css", "javascript", "vim", "html", "lua" },
  config = [[ require('colorizer').setup({'css', 'javascript', 'vim', 'html', 'lua'}) ]],
})

-- Highlights for markdown
use({ "lukas-reineke/headlines.nvim", config = [[ require('headlines').setup() ]] })

-- Highlight blank lines
use({
  "lukas-reineke/indent-blankline.nvim",
  config = [[ require('indent_blankline').setup({ show_current_context = true }) ]],
})

-- Highlight whitespace
use({
  "ntpeters/vim-better-whitespace",
  setup = [[
  -- Don't highlight trailing whitespace for these filetypes
  vim.g.better_whitespace_filetypes_blacklist = {
    "alpha",
    "diff",
    "git",
    "gitcommit",
    "unite",
    "qf",
    "help",
    "markdown",
    "fugitive",
    "dashboard",
    "NvimTree",
    "Outline",
    "Trouble",
    "terminal",
    "toggleterm",
  }
]],
})

-- Highlighting for TODO, FIXME, etc.
use({
  "folke/todo-comments.nvim",
  requires = "nvim-lua/plenary.nvim",
  config = [[ require("todo-comments").setup({}) ]],
})

-- Git, SCM
use({ "lewis6991/gitsigns.nvim", config = [[ require("config.gitsigns") ]] })

-- TODO: Configure this
-- use { "sindrets/diffview.nvim", event = "BufRead" }

-- Wrapping/delimiters
use({ "kylechui/nvim-surround", config = [[ require("config.surround") ]] })

-- Telescope, Search
use({
  {
    "nvim-telescope/telescope.nvim",
    requires = { "nvim-lua/plenary.nvim" },
    after = { "trouble.nvim", "persisted.nvim", "project.nvim" },
    config = [[require('config.telescope')]],
  },
  { "nvim-telescope/telescope-fzf-native.nvim", run = "make" },
  { "nvim-telescope/telescope-ui-select.nvim" },
  { "nvim-telescope/telescope-file-browser.nvim" },
  { "nvim-telescope/telescope-symbols.nvim" },
})

-- Profiling
use({ "dstein64/vim-startuptime", cmd = "StartupTime", config = [[vim.g.startuptime_tries = 10]] })

-- Project Management/Sessions
use({ "olimorris/persisted.nvim", config = [[ require("config.persisted") ]] })
use({ "ahmedkhalf/project.nvim", config = [[ require("config.project") ]] })

-- Navigate seamlessly between kitty and nvim windows.
use({ "knubie/vim-kitty-navigator", run = [[ cp ./*.py $XDG_CONFIG_HOME/kitty/ ]] })

packer.compile() -- since we didn't use packer.startup(), manually compile plugins
