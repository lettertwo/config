return {
  {
    "echasnovski/mini.indentscope",
    opts = {
      symbol = "┆",
      --stylua: ignore
      draw = { delay = 0, animation = function() return 0 end },
      options = {
        border = "both",
        indent_at_cursor = true,
        try_as_border = true,
      },
      mappings = {
        object_scope = "ii",
        object_scope_with_border = "ai",
        goto_top = "[i",
        goto_bottom = "]i",
      },
    },
    config = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = require("lazyvim.config").filetypes.ui,
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
      require("mini.indentscope").setup(opts)
    end,
  },
}
