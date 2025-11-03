return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        -- Proxy LazyVim code group from the builtin LSP group. See :help gra
        { "gr", proxy = "<leader>c", group = "LSP references/actions", icon = { icon = " ", color = "orange" } },
        -- "gra" is mapped in Normal and Visual mode to |vim.lsp.buf.code_action()|
        { "gra", desc = "Code action" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    cmd = { "LspInfo", "LspStart", "LspStop", "LspRestart" },
    keys = {
      {
        "<leader>cL",
        function()
          if next(vim.lsp.get_clients({ bufnr = 0 })) ~= nil then
            vim.cmd("LspStop")
            vim.notify("LSP stopped")
          else
            vim.cmd("LspStart")
            vim.notify("LSP started")
          end
        end,
        desc = "Toggle LSP clients",
      },
    },
    opts = {
      servers = {
        ["*"] = {
          -- stylua: ignore
          keys = {
            { "<leader>.", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeAction" },
            { "grn", function() require("live-rename").rename() end, desc = "Rename (live-rename.nvim)" },
            -- Disable signature help binding in insert mode.
            -- blink.cmp has experimental signature help.
            -- { "<c-k>", false, mode = { "i" } },
          },
        },
      },
    },
  },
}
