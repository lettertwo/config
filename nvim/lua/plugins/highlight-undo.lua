return {
  -- highlight undo/redo events
  {
    "tzachar/highlight-undo.nvim",
    event = "VeryLazy",
    opts = function()
      return {
        ignored_filetypes = LazyVim.config.filetypes.ui,
      }
    end,
  },
}
