return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "mrcjkb/rustaceanvim",
    },
    optional = true,
    opts = function(_, opts)
      vim.list_extend(opts.adapters, { "rustaceanvim.neotest" })
    end,
  },
}
