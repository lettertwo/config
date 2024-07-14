local Util = require("util")

return {
  {
    "mfussenegger/nvim-lint",
    event = "BufReadPost",
    cmd = "Lint",
    keys = {
      { "<leader>ll", "<cmd>Lint<cr>", desc = "Lint document" },
      { "<leader>ul", Util.create_toggle("autolint"), desc = "Toggle autolint" },
    },
    opts = {
      -- Event to trigger linters
      events = { "BufWritePost", "BufReadPost", "InsertLeave" },
      linters_by_ft = Util.ensure_installed({
        python = { "flake8" },
        sh = { "shellcheck" },
      }),
    },
    config = function(_, opts)
      local lint = require("lint")
      lint.linters_by_ft = opts.linters_by_ft

      local debounced_lint = Util.debounce(100, function(args)
        local buf = args ~= nil and args.buf or vim.api.nvim_get_current_buf()
        -- Disable with a global or buffer-local variable
        if vim.g.autolint == false or vim.b[buf].autolint == false then
          return
        end

        -- Disable autolint for files in a certain path
        local bufname = vim.api.nvim_buf_get_name(buf)
        if bufname:match("/node_modules/") then
          return
        end
        return require("lint").try_lint()
      end)

      vim.api.nvim_create_user_command("Lint", debounced_lint, {})

      vim.api.nvim_create_autocmd(opts.events, {
        group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
        callback = debounced_lint,
      })
    end,
  },
  {
    "dmmulroy/tsc.nvim",
    cmd = { "TSC" },
    ft = { "javscript", "javsscriptreact", "typescript", "typescriptreact" },
    opts = {
      auto_open_qflist = false,
      auto_close_qflist = false,
      auto_focus_qflist = false,
      auto_start_watch_mode = false,
      use_trouble_qflist = true,
      use_diagnostics = true,
      -- run_as_monorepo = false,
      -- bin_path = utils.find_tsc_bin(),
      enable_progress_notifications = true,
      flags = {
        -- noEmit = true,
        -- project = function()
        --   return utils.find_nearest_tsconfig()
        -- end,
        watch = true,
      },
      -- hide_progress_notifications_from_history = true,
      -- spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
      pretty_errors = true,
    },
  },
}
