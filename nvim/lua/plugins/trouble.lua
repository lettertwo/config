return {
  {
    "folke/trouble.nvim",
    ---@module "trouble"
    ---@type trouble.Config
    opts = {
      keys = {
        ["<CR>"] = "jump",
        ["<S-CR>"] = "jump_close",
      },
      ---@type table<string, trouble.Mode>
      modes = {
        lsp = {
          win = {
            position = "right",
          },
        },
        diagnostics = {
          mode = "diagnostics",
          focus = true,
          ---@type trouble.Window.opts
          preview = {
            type = "split",
          },
        },
      },
    },
    keys = function()
      return {
        { "<leader>xX", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
        { "<leader>xx", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
      }
    end,
  },
}
