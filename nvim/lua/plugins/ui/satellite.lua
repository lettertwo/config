return {
  -- scrollbar with decorations
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    cmd = { "SatelliteDisable", "SatelliteEnable", "SatelliteRefresh" },
    opts = function(_, opts)
      return vim.tbl_deep_extend("force", opts or {}, {
        excluded_filetypes = LazyVim.config.filetypes.ui,
      })
    end,
  },
}
