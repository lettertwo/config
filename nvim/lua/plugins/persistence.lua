return {
  {
    "folke/persistence.nvim",
    cmd = { "RestoreSession", "RestoreLastSession", "StopSession" },
    opts = { need = 1, branch = true },
    init = function()
      vim.opt.exrc = true -- Enables project-local configuration. See `:h exrc` for more details.
      vim.opt.secure = true -- Require trust to execute exrc files. See `:h secure` for more details.
      -- Set shada file per project/session
      -- from `:h shada`:
      -- > The ShaDa file is used to store:
      -- > - The command line history.
      -- > - The search string history.
      -- > - The input-line history.
      -- > - Contents of non-empty registers.
      -- > - Marks for several files.
      -- > - File marks, pointing to locations in files.
      -- > - Last search/substitute pattern (for 'n' and '&').
      -- > - The buffer list.
      -- > - Global variables.
      local project_file = vim.fs.basename(require("persistence").current())
      local shada_file = vim.fn.fnamemodify(project_file, ":r") .. ".shada"
      vim.opt.shadafile = vim.fs.joinpath(vim.fn.stdpath("state"), "shada", shada_file)
    end,
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
