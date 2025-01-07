return {
  {
    "lukas-reineke/indent-blankline.nvim",
    opts = function(_, opts)
      return vim.tbl_deep_extend("force", opts, {
        indent = { char = "┆" },
        whitespace = { remove_blankline_trail = false },
        scope = { enabled = false },
        exclude = { filetypes = require("lazyvim.config").filetypes.ui },
      })
    end,
  },
}
