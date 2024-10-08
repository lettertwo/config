local Util = require("util")

return {
  {
    "stevearc/conform.nvim",
    event = "BufReadPost",
    cmd = { "Format", "ConformInfo" },
    keys = {
      { "<leader>uf", Util.create_toggle("autoformat"), desc = "Toggle format on save" },
      { "<leader>uF", "<cmd>ConformInfo<cr>", desc = "Show ConformInfo" },
      { "<leader>=", "<cmd>Format<cr>", desc = "Format document" },
      { "<leader>=", "<cmd>Format<cr>", desc = "Format Range", mode = "x" },
    },
    opts = {
      formatters = {
        beautysh = {
          args = { "--indent-size", "2", "--force-function-style", "fnpar", "-" },
        },
      },
      formatters_by_ft = Util.ensure_installed({
        lua = { "stylua" },
        sh = { "beautysh" },
        zsh = { "beautysh" },
        python = { "black" },
        javascript = { "prettierd", "prettier" },
        javascriptreact = { "prettierd", "prettier" },
        typescript = { "prettierd", "prettier" },
        typescriptreact = { "prettierd", "prettier" },
        flowtype = { "prettierd", "prettier" },
        flowtypereact = { "prettierd", "prettier" },
        json = { "prettierd", "prettier" },
        jsonc = { "prettierd", "prettier" },
        yaml = { "prettierd", "prettier" },
        html = { "prettierd", "prettier" },
        css = { "prettierd", "prettier" },
        graphql = { "prettierd", "prettier" },
        markdown = { "prettierd", "prettier" },
      }),
      default_format_opts = {
        timeout_ms = 3000,
        async = false,
        quiet = false,
        lsp_format = "fallback",
        stop_after_first = true,
      },
      format_on_save = function(buf)
        -- Disable with a global or buffer-local variable
        if vim.g.autoformat == false or vim.b[buf].autoformat == false then
          return
        end
        -- Disable autoformat for files in a certain path
        local bufname = vim.api.nvim_buf_get_name(buf)
        if bufname:match("/node_modules/") then
          return
        end
        return { lsp_fallback = true, timeout_ms = 3000 }
      end,
    },
    init = function()
      vim.o.formatexpr = "v:lua.require('conform').formatexpr()"
    end,
    config = function(_, opts)
      require("conform").setup(opts)

      vim.api.nvim_create_user_command("Format", function(args)
        local range = nil
        if args.count ~= -1 then
          local end_line = vim.api.nvim_buf_get_lines(0, args.lines2 - 1, args.lines2, true)[1]
          range = {
            start = { args.line1, 0 },
            ["end"] = { args.line2, end_line:len() },
          }
        end
        require("conform").format({ async = true, lsp_fallback = true, range = range })
      end, { range = true })
    end,
  },
  {
    "echasnovski/mini.align",
    event = { "BufReadPost" },
    opts = {
      mappings = {
        start = "ga",
        start_with_preview = "gA",
      },

      -- Default options controlling alignment process
      options = {
        split_pattern = "",
        justify_side = "left",
        merge_delimiter = "",
      },

      -- Default steps performing alignment (if `nil`, default is used)
      steps = {
        pre_split = {},
        split = nil,
        pre_justify = {},
        justify = nil,
        pre_merge = {},
        merge = nil,
      },

      -- Whether to disable showing non-error feedback
      silent = false,
    },
  },
}
