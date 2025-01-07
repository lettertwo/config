return {
  {
    "mfussenegger/nvim-lint",
    cond = vim.g.mergetool ~= true,
    opts = {
      linters_by_ft = {
        bash = { "bash" },
        zsh = { "zsh" },
      },
    },
  },
  -- {
  --   "dmmulroy/tsc.nvim",
  --   cmd = { "TSC" },
  --   ft = { "javscript", "javsscriptreact", "typescript", "typescriptreact" },
  --   opts = {
  --     auto_open_qflist = false,
  --     auto_close_qflist = false,
  --     auto_focus_qflist = false,
  --     auto_start_watch_mode = false,
  --     use_trouble_qflist = true,
  --     use_diagnostics = true,
  --     -- run_as_monorepo = false,
  --     -- bin_path = utils.find_tsc_bin(),
  --     enable_progress_notifications = true,
  --     flags = {
  --       -- noEmit = true,
  --       -- project = function()
  --       --   return utils.find_nearest_tsconfig()
  --       -- end,
  --       watch = true,
  --     },
  --     -- hide_progress_notifications_from_history = true,
  --     -- spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
  --     pretty_errors = true,
  --   },
  -- },
}
