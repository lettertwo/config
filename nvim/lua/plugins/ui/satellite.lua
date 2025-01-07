return {
  -- scrollbar with decorations
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    cmd = { "SatelliteDisable", "SatelliteEnable", "SatelliteRefresh" },
    opts = function()
      local filetypes = require("lazyvim.config").filetypes
      return {
        excluded_filetypes = filetypes.ui,
      }
    end,
  },
}
