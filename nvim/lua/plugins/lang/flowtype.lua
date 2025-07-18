return {
  {
    "nvim-treesitter/nvim-treesitter",
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      ensure_installed = { "tsx" },
    },
    ---@param opts TSConfig
    config = function(_, opts)
      -- Associate the flowtype filetypes with the typescript parser.
      vim.treesitter.language.register("tsx", "flowtypereact")
      vim.treesitter.language.register("tsx", "flowtype")
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
