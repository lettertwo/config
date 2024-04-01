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
}
