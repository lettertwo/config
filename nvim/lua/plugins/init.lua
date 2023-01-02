return {
  -- Navigate seamlessly between kitty and nvim windows.
  { "knubie/vim-kitty-navigator", build = [[ cp ./*.py $XDG_CONFIG_HOME/kitty/ ]] },

  -- Package manager for LSP, DAP, Linting, Formatting, etc.
  {
    "williamboman/mason.nvim",
    event = "VeryLazy",
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })
    end,
  },

  { "folke/which-key.nvim", event = "VeryLazy" },

  {
    "TaDaa/vimade", -- Fade inactive windows while preserving syntax highlights.
    event = "VeryLazy",
    init = function()
      vim.g.vimade = {
        fadelevel = 0.7,
        enablesigns = 1,
        enablefocusfading = 1,
        enabletreesitter = 1,
      }
    end,
  },

  -- Icons used by lots of other nvim plugins
  { "kyazdani42/nvim-web-devicons", config = true },

  -- A common dependency in lua plugins. Also useful for testing plugins.
  { "nvim-lua/plenary.nvim" },

  -- Highlight colors
  {
    "norcalli/nvim-colorizer.lua",
    event = "BufReadPost",
    ft = { "css", "javascript", "vim", "html", "lua" },
    config = function()
      require("colorizer").setup({ "css", "javascript", "vim", "html", "lua" })
    end,
  },

  -- Highlights for markdown
  { "lukas-reineke/headlines.nvim", event = "BufReadPost", config = true },

  -- Highlight blank lines
  {
    "lukas-reineke/indent-blankline.nvim",
    event = "BufReadPost",
    config = function()
      require("indent_blankline").setup({ show_current_context = true })
    end,
  },

  -- Highlight whitespace
  {
    "ntpeters/vim-better-whitespace",
    event = "BufReadPost",
    init = function()
      -- Don't highlight trailing whitespace for these filetypes
      vim.g.better_whitespace_filetypes_blacklist = vim.list_extend({
        "diff",
        "git",
        "gitcommit",
        "markdown",
      }, vim.g.ui_filetypes)
    end,
  },

  -- Highlighting for TODO, FIXME, etc.
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = "nvim-lua/plenary.nvim",
    config = true,
  },

  -- Scrollbar
  {
    "petertriho/nvim-scrollbar",
    event = "BufReadPost",
    config = function()
      require("scrollbar").setup({
        excluded_filetypes = vim.g.ui_filetypes,
      })
      require("scrollbar.handlers.gitsigns").setup()
    end,
  },

  -- TODO:: Lua plugin development --
  -- use("nanotee/luv-vimdocs")
  -- use("milisims/nvim-luaref")
  -- use("bfredl/nvim-luadev")
  -- use("folke/neodev.nvim")

  -- Occurrence operator --
  -- use({ "~/.local/share/occurrency.nvim", config = [[ require("occurrency.dev").setup({}) ]] })

  -- Multi-cursor selection
  -- use({ "mg979/vim-visual-multi", setup = [[ require("plugins.visual-multi") ]] })

  -- TODO: Configure this
  -- use({ "sindrets/diffview.nvim", event = "BufRead" })

  -- Session management
  {
    "olimorris/persisted.nvim",
    config = function()
      require("persisted").setup({
        use_git_branch = true,
        autosave = true,
        allowed_dirs = {
          "~/.config",
          "~/Code",
          "~/.local/share",
        },
        after_source = function()
          -- Reload the LSP servers
          vim.lsp.stop_client(vim.lsp.get_active_clients(), true)
        end,
        telescope = {
          before_source = function()
            -- Close all open buffers
            vim.api.nvim_input("<ESC>:%bd<CR>")
          end,
          after_source = function(session)
            print("Loaded session " .. session.name)
          end,
        },
      })
    end,
  },

  -- Project management
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        detection_methods = { "pattern", "lsp" },
        patterns = { ".git", ".hg", ".bzr", ".svn" },
        show_hidden = true,
        silent_chdir = false,
      })
    end,
  },

  -- Markdown previews
  -- use({ "toppair/peek.nvim", run = "deno task --quiet build:fast", config = [[ require("peek").setup({}) ]] })

  -- use 'mhinz/vim-sayonara'

  -- Undo tree
  -- use {
  --   'mbbill/undotree',
  --   cmd = 'UndotreeToggle',
  --   config = [[vim.g.undotree_SetFocusWhenToggle = 1]],
  -- }

  -- Debugger
  -- use({
  --   "mfussenegger/nvim-dap",
  --   requires = {
  --     "rcarriga/nvim-dap-ui",
  --     "theHamsta/nvim-dap-virtual-text",
  --     "mxsdev/nvim-dap-vscode-js",
  --     "jayp0521/mason-nvim-dap.nvim",
  --   },
  --   wants = { "microsoft/vscode-js-debug" },
  --   after = { "mason.nvim" },
  --   setup = [[
  --     vim.g.dap_virtual_text = true
  --   ]],
  --   config = [[require('plugins.dap')]],
  -- })
  --
  -- use({
  --   "vim-test/vim-test",
  --   setup = [[
  --   vim.g["test#strategy"] = "kitty"
  -- ]],
  -- })

  -- See: https://github.com/mxsdev/nvim-dap-vscode-js#debugger
  -- TODO: Figure out if this can be managed via Mason.
  -- use({
  --   "microsoft/vscode-js-debug",
  --   opt = true,
  --   run = "npm install --legacy-peer-deps && npm run compile",
  -- })
}
