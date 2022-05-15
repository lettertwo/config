-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile

-- LunarVim Builtins
require("user.plugins.bufferline").config()
require("user.plugins.cmp").config()
require("user.plugins.dap").config()
require("user.plugins.dashboard").config()
require("user.plugins.lualine").config()
require("user.plugins.notify").config()
require("user.plugins.nvim-tree").config()
require("user.plugins.telescope").config()
require("user.plugins.treesitter").config()
require("user.plugins.which-key").config()

-- Additional Plugins
lvim.plugins = {
  {
    "lettertwo/laserwave.nvim",
    requires = { "rktjmp/lush.nvim" },
  },
  {
    "folke/trouble.nvim",
    config = function()
      require("user.plugins.trouble").config()
    end,
  },
  { "simrat39/symbols-outline.nvim", cmd = "SymbolsOutline" },
  { "ntpeters/vim-better-whitespace" },
  { "sindrets/diffview.nvim", event = "BufRead" },
  { "f-person/git-blame.nvim", event = "BufRead" },
  {
    "olimorris/persisted.nvim",
    config = function()
      require("user.plugins.persisted").config()
    end,
  },
  {
    "norcalli/nvim-colorizer.lua",
    config = function()
      require("user.plugins.colorizer").config()
    end,
  },
  {
    "folke/todo-comments.nvim",
    event = "BufRead",
    config = function()
      require("todo-comments").setup()
    end,
  },
  { "nvim-treesitter/playground", event = "BufRead" },
  { "nvim-treesitter/nvim-treesitter-textobjects" },
  { "RRethy/nvim-treesitter-textsubjects" },
  { "andymass/vim-matchup" },
  -- "sa" to add surround, "sd" to delete, "sr" to replace
  { "machakann/vim-sandwich" },
  { "knubie/vim-kitty-navigator" },
  { "TaDaa/vimade" },
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function()
      require("lsp_signature").setup({ hint_enable = false })
      require("lsp_signature").on_attach()
    end,
  },

  { "github/copilot.vim" },
  { "petertriho/cmp-git", requires = "nvim-lua/plenary.nvim" },
  { "tamago324/cmp-zsh" },
  { "lukas-reineke/cmp-under-comparator" },
  { "hrsh7th/cmp-nvim-lua" },
}
