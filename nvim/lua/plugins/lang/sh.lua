return {
  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { "beautysh" } },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        bash = { "bash" },
        zsh = { "zsh" },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      default_format_opts = {
        stop_after_first = true,
      },
      formatters = {
        beautysh = {
          args = { "--indent-size", "2", "--force-function-style", "fnpar", "-" },
        },
      },
      formatters_by_ft = {
        sh = { "beautysh" },
        zsh = { "beautysh" },
      },
    },
  },
}
