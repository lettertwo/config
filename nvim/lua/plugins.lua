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
use "wbthomason/packer.nvim"       -- Packer can manage itself
use 'lewis6991/impatient.nvim'     -- Gotta go fast
use "nvim-lua/plenary.nvim"        -- A common dependency in lua plugins
use "kyazdani42/nvim-web-devicons" -- Icons used by lots of other nvim plugins

-- some assembly required --
use { "folke/which-key.nvim", config = [[ require("keymap") ]] }
use { "numToStr/Comment.nvim", config = [[ require("config.comment") ]] }

-- Status bar --
use { "nvim-lualine/lualine.nvim", config = [[ require("config.lualine") ]] }

-- Colorscheme --
use { "~/.local/share/laserwave", requires = { "rktjmp/lush.nvim", "rktjmp/shipwright.nvim" } }

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

-- Treesitter
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

packer.compile() -- since we didn't use packer.startup(), manually compile plugins

