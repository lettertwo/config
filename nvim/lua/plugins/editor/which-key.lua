return {
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts.preset = "modern"
      opts.disable = { ft = require("lazyvim.config").filetypes.ui }
      opts.delay = function(ctx)
        return ctx.mode == "x" and 500 or 0
      end

      -- Disable expands for groups in the default spec, e.g.,
      -- numeric mappings for open buffers and windows.
      opts.spec[1] = vim.tbl_map(function(item)
        item.expand = nil
        return item
      end, opts.spec[1])

      return opts
    end,
  },
}
