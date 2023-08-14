return {
  -- Navigate seamlessly between kitty and nvim windows.
  { "knubie/vim-kitty-navigator", build = [[ cp ./*.py $XDG_CONFIG_HOME/kitty/ ]] },

  -- A common dependency in lua plugins. Also useful for testing plugins.
  { "nvim-lua/plenary.nvim" },

  -- makes some plugins dot-repeatable like leap
  { "tpope/vim-repeat", event = "VeryLazy" },

  -- measure startuptime
  {
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    config = function()
      vim.g.startuptime_tries = 10
    end,
  },

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

  -- session management
  {
    "folke/persistence.nvim",
    event = "BufReadPost",
    opts = { options = { "buffers", "curdir", "tabpages", "winsize", "help" } },
    -- stylua: ignore
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
    config = function(_, opts)
      require("persistence").setup(opts)
      -- autocmd to disable session saving for git operations
      -- FIXME: This will cause session saving to be disabled for the rest of the session,
      -- which is ok in the case where nvim is started via a git command,
      -- but not ok if nvim was already running.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("persistence", { clear = true }),
        pattern = { "gitcommit", "gitrebase", "gitconfig" },
        callback = require("persistence").stop,
      })
    end,
  },

  -- crate management
  {
    "saecki/crates.nvim",
    opts = {
      null_ls = {
        enabled = true,
        name = "crates.nvim",
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>ct", function() require("crates").toggle() end, desc = "toggle" },
      { "<leader>cr", function() require("crates").reload() end, desc = "reload" },
      { "<leader>cv", function() require("crates").show_versions_popup() end, desc = "show_versions_popup" },
      { "<leader>cf", function() require("crates").show_features_popup() end, desc = "show_features_popup" },
      { "<leader>cd", function() require("crates").show_dependencies_popup() end, desc = "show_dependencies_popup" },
      { "<leader>cu", function() require("crates").update_crate() end, desc = "update_crate" },
      { "<leader>cu", function() require("crates").update_crates() end, desc = "update_crates" },
      { "<leader>ca", function() require("crates").update_all_crates() end, desc = "update_all_crates" },
      { "<leader>cU", function() require("crates").upgrade_crate() end, desc = "upgrade_crate" },
      { "<leader>cA", function() require("crates").upgrade_all_crates() end, desc = "upgrade_all_crates" },
      { "<leader>cH", function() require("crates").open_homepage() end, desc = "open_homepage" },
      { "<leader>cR", function() require("crates").open_repository() end, desc = "open_repository" },
      { "<leader>cD", function() require("crates").open_documentation() end, desc = "open_documentation" },
      { "<leader>cC", function() require("crates").open_crates_io() end, desc = "open_crates_io" },
      -- {'v', '<leader>cU', crates.upgrade_crates, opts)
    },
  },
}
