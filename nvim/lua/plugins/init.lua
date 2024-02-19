return {
  {
    "craigmac/Navigator.nvim",
    cmd = { "NavigatorLeft", "NavigatorRight", "NavigatorUp", "NavigatorDown", "NavigatorPrevious" },
    keys = {
      { "<c-h>", "<cmd>NavigatorLeft<cr>", desc = "NavigatorLeft" },
      { "<c-l>", "<cmd>NavigatorRight<cr>", desc = "NavigatorRight" },
      { "<c-k>", "<cmd>NavigatorUp<cr>", desc = "NavigatorUp" },
      { "<c-j>", "<cmd>NavigatorDown<cr>", desc = "NavigatorDown" },
      -- { "<CTRL-p>", "<cmd>NavigatorPrevious</cr>" },
    },
    opts = {},
  },

  -- A common dependency in lua plugins. Also useful for testing plugins.
  { "nvim-lua/plenary.nvim" },

  -- makes some plugins dot-repeatable like leap
  { "tpope/vim-repeat", event = "VeryLazy" },

  -- measure startuptime
  {
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    config = true,
    init = function()
      vim.g.startuptime_tries = 10
    end,
  },

  -- profiler
  {
    "stevearc/profile.nvim",
    init = function()
      local should_profile = os.getenv("NVIM_PROFILE")

      if should_profile then
        require("profile").instrument_autocmds()
        if should_profile:lower():match("^start") then
          require("profile").start("*")
        else
          require("profile").instrument("*")
        end
      end

      local function toggle_profile()
        local prof = require("profile")
        if prof.is_recording() then
          prof.stop()
          vim.ui.input(
            { prompt = "Save profile to:", completion = "file", default = "profile.json" },
            function(filename)
              if filename then
                prof.export(filename)
                vim.notify(string.format("Wrote %s", filename))
              end
            end
          )
        else
          prof.start("*")
        end
      end

      -- local function toggle_profile()
      --   if vim.v.profiling == 1 then
      --     vim.cmd([[ profile pause | profile dump | noautocmd qall! ]])
      --   else
      --     vim.cmd([[ profile start profile.log | profile func * | profile file * ]])
      --   end
      -- end

      vim.keymap.set("", "<C-p>", toggle_profile, { desc = "Toggle profile" })
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
      -- TODO: Implement telescope integration like:
      -- https://github.com/olimorris/persisted.nvim/tree/main/lua/telescope/_extensions/persisted
      -- maybe using https://github.com/folke/persistence.nvim/blob/main/lua/persistence/init.lua#L53C12-L53C16
      require("persistence").setup(opts)
      -- autocmd to disable session saving for git operations
      -- FIXME: This will cause session saving to be disabled for the rest of the session,
      -- which is ok in the case where nvim is started via a git command,
      -- but not ok if nvim was already running.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("persistence", { clear = false }),
        pattern = { "gitcommit", "gitrebase", "gitconfig" },
        callback = require("persistence").stop,
      })
    end,
  },

  -- package info
  {
    "vuki656/package-info.nvim",
    cmd = { "PackageInfoShow" },
    ft = { "json" },
    -- stylua: ignore start
    keys = {
      { "<leader>nt", function() require("package-info").toggle() end, desc = "Toggle dependency versions" },
      { "<leader>nu", function() require("package-info").update() end, desc = "Update dependency on the line" },
      { "<leader>nd", function() require("package-info").delete() end, desc = "Delete dependency on the line" },
      { "<leader>ni", function() require("package-info").install() end, desc = "Install a new dependency" },
      { "<leader>np", function() require("package-info").change_version() end, desc = "Install a different dependency version" },
    },
    -- stylua: ignore end
    opts = {
      autostart = false,
      hide_up_to_date = true,
    },
  },

  -- crate management
  {
    "saecki/crates.nvim",
    opts = {
      src = {
        cmp = {
          enabled = true,
        },
      },
      null_ls = {
        enabled = true,
        name = "crates.nvim",
      },
    },
    -- stylua: ignore start
    keys = {
      { "<leader>Ct", function() require("crates").toggle() end, desc = "toggle" },
      { "<leader>Cr", function() require("crates").reload() end, desc = "reload" },
      { "<leader>Cv", function() require("crates").show_versions_popup() end, desc = "show_versions_popup" },
      { "<leader>Cf", function() require("crates").show_features_popup() end, desc = "show_features_popup" },
      { "<leader>Cd", function() require("crates").show_dependencies_popup() end, desc = "show_dependencies_popup" },
      { "<leader>Cu", function() require("crates").update_crate() end, desc = "update_crate" },
      { "<leader>Cu", function() require("crates").update_crates() end, desc = "update_crates" },
      { "<leader>Ca", function() require("crates").update_all_crates() end, desc = "update_all_crates" },
      { "<leader>CU", function() require("crates").upgrade_crate() end, desc = "upgrade_crate" },
      { "<leader>CA", function() require("crates").upgrade_all_crates() end, desc = "upgrade_all_crates" },
      { "<leader>CH", function() require("crates").open_homepage() end, desc = "open_homepage" },
      { "<leader>CR", function() require("crates").open_repository() end, desc = "open_repository" },
      { "<leader>CD", function() require("crates").open_documentation() end, desc = "open_documentation" },
      { "<leader>CC", function() require("crates").open_crates_io() end, desc = "open_crates_io" },
      -- {'v', '<leader>cU', crates.upgrade_crates, opts)
    },
    -- stylua: ignore end
  },

  {
    event = "BufReadPost",
    dir = "~/.local/share/occurrence.nvim",
    name = "occurrence.nvim",
    config = function()
      require("occurrence.dev").setup()
    end,
  },

  {
    event = "VeryLazy",
    dir = "~/.local/share/fixlist.nvim/main",
    name = "fixlist.nvim",
    config = function()
      require("fixlist.dev").setup()
    end,
  },
}
