return {
  -- scrollbar with decorations
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    cmd = { "SatelliteDisable", "SatelliteEnable", "SatelliteRefresh" },
    opts = function()
      return {
        excluded_filetypes = LazyVim.config.filetypes.ui,
        handlers = {
          marks = {
            key = LazyVim.config.icons.tag,
          },
        },
      }
    end,
  },
}
