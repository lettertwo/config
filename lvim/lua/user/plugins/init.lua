-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile

-- LunarVim Builtins
require("user.plugins.bufferline").config()
require("user.plugins.cmp").config()
require("user.plugins.dap").config()
require("user.plugins.dashboard").config()
require("user.plugins.lualine").config()
require("user.plugins.notify").config()
require("user.plugins.telescope").config()
require("user.plugins.treesitter").config()
require("user.plugins.which-key").config()

-- Additional Plugins
lvim.plugins = {
  -- colorscheme
  {
    "~/.local/share/laserwave",
    requires = { "rktjmp/lush.nvim", "rktjmp/shipwright.nvim" },
  },

  -- Projects, Sessions, etc.
  {
    "olimorris/persisted.nvim",
    config = function()
      require("user.plugins.persisted").config()
    end,
  },

  -- LSP, diagnostics
  {
    "folke/trouble.nvim",
    config = function()
      require("user.plugins.trouble").config()
    end,
  },
  { "ntpeters/vim-better-whitespace" },
  { "romainl/vim-qf" }, -- Quickfix enhancements. See :help vim-qf
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function()
      require("lsp_signature").setup({ hint_enable = false })
      require("lsp_signature").on_attach()
    end,
  },

  -- Treesitter, highlighting
  { "simrat39/symbols-outline.nvim", cmd = "SymbolsOutline" },
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

  -- cmp
  { "github/copilot.vim" },
  { "petertriho/cmp-git", requires = "nvim-lua/plenary.nvim" },
  { "tamago324/cmp-zsh" },
  { "lukas-reineke/cmp-under-comparator" },
  { "hrsh7th/cmp-nvim-lua" },

  -- Git, SCM
  { "sindrets/diffview.nvim", event = "BufRead" },
  { "f-person/git-blame.nvim", event = "BufRead" },

  -- Window management
  { "TaDaa/vimade" },

  -- pairs, surrounds, splits, joins
  { "andymass/vim-matchup" },
  { "machakann/vim-sandwich" }, -- "sa" to add surround, "sd" to delete, "sr" to replace
  { "AndrewRadev/splitjoin.vim", keys = { "gJ", "gS" } },

  -- navigation
  { "knubie/vim-kitty-navigator" },
  { "unblevable/quick-scope" },

  -- Visualize and search the Undo tree.
  { "mbbill/undotree" },

  -- Telescope extensions
  { "nvim-telescope/telescope-ui-select.nvim" },
  { "nvim-telescope/telescope-file-browser.nvim" },
  { "nvim-telescope/telescope-symbols.nvim" },

  -- Debugger
  { "rcarriga/nvim-dap-ui" },
  { "theHamsta/nvim-dap-virtual-text" },

  -- misc
  { "dstein64/vim-startuptime", cmd = "StartupTime" },
}
