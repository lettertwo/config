return {
  {
    "folke/persistence.nvim",
    cmd = { "RestoreSession", "RestoreLastSession", "StopSession" },
    opts = { need = 1, branch = true },
    -- stylua: ignore
    keys = {
      { "<leader>qs", function() require("persistence").select() end, desc = "Select Session" },
      { "<leader>ql", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
    config = function(_, opts)
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
