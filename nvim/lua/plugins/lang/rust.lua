return {
  {
    "nvim-neotest/neotest",
    opts = function(_, opts)
      local local_opts = {
        adapters = {
          require("rustaceanvim.neotest"),
        },
      }
      return vim.tbl_deep_extend("force", opts or {}, local_opts)
    end,
  },
}
