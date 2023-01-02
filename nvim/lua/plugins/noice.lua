return {
  -- UI for notifications, messages, cmdline, LSP status, etc. --
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    config = function()
      require("noice").setup({
        lsp = {
          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
          hover = { enabled = false }, -- Using a custom hover handler. See `config.lsp`.
        },
        presets = {
          long_message_to_split = true, -- long messages will be sent to a split
          command_palette = true, -- position the cmdline and popupmenu together
          lsp_doc_border = true, -- add a border to hover docs and signature help
        },
        routes = {
          {
            view = "notify",
            filter = { event = "msg_showmode" },
          },
          {
            filter = {
              event = "msg_show",
              kind = "",
              find = "written",
            },
            opts = { skip = true },
          },
        },
      })
    end,
  },
}
