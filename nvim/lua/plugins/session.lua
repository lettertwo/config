return {
  -- session management
  {
    "folke/persistence.nvim",
    event = "BufReadPost",
    cmd = { "RestoreSession", "RestoreLastSession", "StopSession" },
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

      vim.api.nvim_create_user_command("RestoreSession", function()
        require("persistence").load()
      end, { desc = "Restore Session" })

      vim.api.nvim_create_user_command("RestoreLastSession", function()
        require("persistence").load({ last = true })
      end, { desc = "Restore Last Session" })

      vim.api.nvim_create_user_command("StopSession", function()
        require("persistence").stop()
      end, { desc = "Don't Save Current Session" })
    end,
  },
}
