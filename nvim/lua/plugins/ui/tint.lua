return {
  -- Fade inactive windows while preserving syntax highlights.
  {
    "levouh/tint.nvim",
    event = "VeryLazy",
    opts = {
      tint = -50,
      saturation = 0.5,
      highlight_ignore_patterns = { "WinSeparator", "Status.*", "IndentBlankline*" },
    },
  },
}
