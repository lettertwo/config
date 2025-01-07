return {
  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { "beautysh" } },
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.default_format_opts.stop_after_first = true

      opts.formatters.beautysh = {
        args = { "--indent-size", "2", "--force-function-style", "fnpar", "-" },
      }
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      for _, ft in ipairs({ "sh", "zsh" }) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        table.insert(opts.formatters_by_ft[ft], "beautysh")
      end
    end,
  },
  -- {
  --   "echasnovski/mini.align",
  --   event = { "BufReadPost" },
  --   opts = {
  --     mappings = {
  --       start = "ga",
  --       start_with_preview = "gA",
  --     },
  --
  --     -- Default options controlling alignment process
  --     options = {
  --       split_pattern = "",
  --       justify_side = "left",
  --       merge_delimiter = "",
  --     },
  --
  --     -- Default steps performing alignment (if `nil`, default is used)
  --     steps = {
  --       pre_split = {},
  --       split = nil,
  --       pre_justify = {},
  --       justify = nil,
  --       pre_merge = {},
  --       merge = nil,
  --     },
  --
  --     -- Whether to disable showing non-error feedback
  --     silent = false,
  --   },
  -- },
}
