local ok, packer = pcall(require, "packer")
if not ok then return end

packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({border = "rounded"})
    end,
  },
})

local use = packer.use
packer.reset()

-- "always on" plugins; no setup necessary! --
use "wbthomason/packer.nvim"          -- Packer can manage itself
use 'lewis6991/impatient.nvim'        -- Gotta go fast
use "nvim-lua/plenary.nvim"           -- A common dependency in lua plugins
use "kyazdani42/nvim-web-devicons"    -- Icons used by lots of other nvim plugins
use "antoinemadec/FixCursorHold.nvim" -- Workaround for bugs with neovim cursorhold autocmds
use { "TaDaa/vimade",                 -- Fade inactive windows while preserving syntax highlights.
  setup = [[
    vim.g.vimade = {
    fadelevel = 0.7,
    enablesigns = 1,
    enablefocusfading = 1,
    enabletreesitter = 1,
  }
]]}

-- Colorscheme --
use { "~/.local/share/laserwave", requires = { "rktjmp/lush.nvim", "rktjmp/shipwright.nvim" } }

-- some assembly required --
use { "folke/which-key.nvim", config = [[ require("keymap") ]] }
use { "numToStr/Comment.nvim", config = [[ require("config.comment") ]] }

-- Status bar, Tab bar, location --
use { "nvim-lualine/lualine.nvim",
  requires = { "SmiteshP/nvim-navic", "SmiteshP/nvim-gps" },
  after = { "nvim-lspconfig", "nvim-treesitter" },
  config = [[ require("config.lualine") ]]
}

-- Copilot (RIP my job)
use { "github/copilot.vim", setup = [[
  -- Accepting copilot suggestions is managed via nvim-cmp config.
  vim.g.copilot_no_tab_map = true -- Don't use default <Tab> binding.
  vim.g.copilot_assume_mapped = true -- A key is mapped (via cmp config) to accept copilot suggestions.
]] }

-- Completion
use {
  'hrsh7th/nvim-cmp',
  requires = {
    { 'L3MON4D3/LuaSnip', requires = { { "rafamadriz/friendly-snippets" } } },
    { 'hrsh7th/cmp-buffer' },
    { 'hrsh7th/cmp-nvim-lsp' },
    { 'hrsh7th/cmp-nvim-lsp-signature-help' },
    { 'hrsh7th/cmp-path' },
    { 'hrsh7th/cmp-nvim-lua' },
    { 'saadparwaiz1/cmp_luasnip' },
    { 'lukas-reineke/cmp-under-comparator' },
    { 'hrsh7th/cmp-nvim-lsp-document-symbol' },
    { "hrsh7th/cmp-calc" },
    { "hrsh7th/cmp-cmdline" },
    { "dmitmel/cmp-cmdline-history" },
    { "petertriho/cmp-git" },
  },
  config = [[require('config.cmp')]],
}

-- LSP
use {
  "neovim/nvim-lspconfig",
  requires = {
    "williamboman/nvim-lsp-installer",
    "ray-x/lsp_signature.nvim",
    "kosayoda/nvim-lightbulb",
  },
  after = "cmp-nvim-lsp",
  config = [[ require("config.lsp") ]],
}

-- Linting
use { "jose-elias-alvarez/null-ls.nvim", after = "nvim-lspconfig", config = [[ require("config.null-ls") ]] }

-- Diagnostics
use { "folke/trouble.nvim", after = "nvim-lspconfig", config = [[ require("config.diagnostics") ]] }

-- Treesitter and Highlighting
use {
  'nvim-treesitter/nvim-treesitter',
  requires = {
    'nvim-treesitter/nvim-treesitter-textobjects',
    'nvim-treesitter/nvim-treesitter-refactor',
    'RRethy/nvim-treesitter-textsubjects',
    'RRethy/nvim-treesitter-endwise',
    "JoosepAlviste/nvim-ts-context-commentstring",
  },
  run = ':TSUpdate',
  config = [[ require("config.treesitter") ]],
}
-- Highlight colors
use {
  'norcalli/nvim-colorizer.lua',
  ft = { 'css', 'javascript', 'vim', 'html', 'lua' },
  config = [[ require('colorizer').setup({'css', 'javascript', 'vim', 'html', 'lua'}) ]],
}

-- Highlights for markdown
use { 'lukas-reineke/headlines.nvim', config = [[ require('headlines').setup() ]] }

-- Highlight blank lines
use {
  "lukas-reineke/indent-blankline.nvim",
  config = [[ require('indent_blankline').setup({ show_current_context = true }) ]]
}

-- Highlight whitespace
use { "ntpeters/vim-better-whitespace", setup = [[
  -- Don't highlight trailing whitespace for these filetypes
  vim.g.better_whitespace_filetypes_blacklist = {
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
  }
]] }

-- Git, SCM
use { "lewis6991/gitsigns.nvim", config = [[ require("config.gitsigns") ]] }

-- TODO: Configure this
-- use { "sindrets/diffview.nvim", event = "BufRead" }

-- Wrapping/delimiters
use { "~/Code/nvim-surround", config = [[ require("config.surround") ]] }

-- Telescope, Search
use {
  {
    'nvim-telescope/telescope.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
    config = [[require('config.telescope')]],
  },
  { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' },
  { "nvim-telescope/telescope-ui-select.nvim" },
  { "nvim-telescope/telescope-file-browser.nvim" },
  { "nvim-telescope/telescope-symbols.nvim" },
}

-- Profiling
use { 'dstein64/vim-startuptime', cmd = 'StartupTime', config = [[vim.g.startuptime_tries = 10]] }

packer.compile() -- since we didn't use packer.startup(), manually compile plugins

