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

-- some assembly required --
use { "folke/which-key.nvim", config = [[ require("keymap") ]] }
use { "numToStr/Comment.nvim", config = [[ require("config.comment") ]] }

-- Status bar --
use { "nvim-lualine/lualine.nvim", config = [[ require("config.lualine") ]] }

-- Colorscheme --
use { "~/.local/share/laserwave", requires = { "rktjmp/lush.nvim", "rktjmp/shipwright.nvim" } }

-- LSP and linting
use {
  "neovim/nvim-lspconfig",
  requires = {
    { "jose-elias-alvarez/null-ls.nvim", after = "nvim-lspconfig", config = [[ require("config.null-ls") ]] },
    "williamboman/nvim-lsp-installer",
    "ray-x/lsp_signature.nvim",
    "kosayoda/nvim-lightbulb",
  },
  config = [[ require("config.lsp") ]],
}

-- Diagnostics
use { "folke/trouble.nvim", after = "nvim-lspconfig", config = [[ require("config.diagnostics") ]] }

-- Completion
use {
  'hrsh7th/nvim-cmp',
  requires = {
    { 'L3MON4D3/LuaSnip', requires = { { "rafamadriz/friendly-snippets" } } },
    { 'hrsh7th/cmp-buffer', after = 'nvim-cmp' },
    { 'hrsh7th/cmp-nvim-lsp', after = 'nvim-cmp' },
    { 'hrsh7th/cmp-nvim-lsp-signature-help', after = 'nvim-cmp' },
    { 'hrsh7th/cmp-path', after = 'nvim-cmp' },
    { 'hrsh7th/cmp-nvim-lua', after = 'nvim-cmp' },
    { 'saadparwaiz1/cmp_luasnip', after = 'nvim-cmp' },
    { 'lukas-reineke/cmp-under-comparator', after = 'nvim-cmp' },
    { 'hrsh7th/cmp-nvim-lsp-document-symbol', after = 'nvim-cmp' },
    { "hrsh7th/cmp-calc", after = "nvim-cmp" },
    { "hrsh7th/cmp-cmdline", after = "nvim-cmp" },
    { "dmitmel/cmp-cmdline-history", after = "nvim-cmp" },
    { "github/copilot.vim", after = "nvim-cmp" },
  },
  config = [[require('config.cmp')]],
}

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

-- Window, buffer management
use { "TaDaa/vimade", setup = [[
  -- Fade inactive windows while preserving syntax highlights.
  vim.g.vimade = {
    fadelevel = 0.7,
    enablesigns = 1,
    enablefocusfading = 1,
    enabletreesitter = 1,
  }
]]}

packer.compile() -- since we didn't use packer.startup(), manually compile plugins

