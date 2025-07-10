return {
  {
    "nvim-treesitter/nvim-treesitter",
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      highlight = {
        additional_vim_regex_highlighting = { "markdown" },
      },
    },
  },
}
