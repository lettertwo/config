return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        -- Proxy LazyVim code group from the builtin LSP group. See :help gra
        { "gr", proxy = "<leader>c", group = "LSP references/actions", icon = { icon = " ", color = "orange" } },
        -- "gra" is mapped in Normal and Visual mode to |vim.lsp.buf.code_action()|
        { "gra", desc = "Code action" },
        -- "grn" is mapped in Normal mode to |vim.lsp.buf.rename()|
        { "grn", desc = "Rename (inc-rename.nvim)" },
        -- "grr" is mapped in Normal mode to |vim.lsp.buf.references()|
        { "grr", desc = "Show references" },
        -- "gri" is mapped in Normal mode to |vim.lsp.buf.implementation()|
        { "gri", desc = "Show implementations" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    cond = vim.g.mergetool ~= true,
    cmd = { "LspInfo", "LspStart", "LspStop", "LspRestart" },
    keys = {
      {
        "<leader>cL",
        function()
          if next(vim.lsp.get_clients()) ~= nil then
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
    opts = function()
      local function rename()
        local inc_rename = require("inc_rename")
        return ":" .. inc_rename.config.cmd_name .. " " .. vim.fn.expand("<cword>")
      end

      vim.list_extend(require("lazyvim.plugins.lsp.keymaps").get(), {
        { "<leader>.", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeAction" },
        { "grn", rename, expr = true, desc = "Rename (inc-rename.nvim)" },
        -- Disable these keymaps from the picker extras (fzf, telescope).
        -- They conflict with both the builtin keymaps and Glance functionality.
        { "gd", false },
        { "gD", false },
        { "gr", false },
        { "gI", false },
        { "gy", false },
        -- Disable signature help binding in insert mode.
        -- blink.cmp has experimental signature help.
        { "<c-k>", false, mode = { "i" } },
      })
    end,
  },
}
