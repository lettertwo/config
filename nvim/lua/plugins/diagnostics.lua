local signs = {
  { name = "DiagnosticSignError", text = "" },
  { name = "DiagnosticSignWarn", text = "" },
  { name = "DiagnosticSignHint", text = "" },
  { name = "DiagnosticSignInfo", text = "" },
}

for _, sign in ipairs(signs) do
  vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
end

vim.diagnostic.config({
  virtual_text = true,
  signs = {
    active = signs,
  },
  update_in_insert = true,
  underline = true,
  severity_sort = true,
  float = {
    focusable = false,
    style = "minimal",
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
})

return {
  {
    "folke/trouble.nvim",
    event = "VeryLazy",
    config = function()
      require("trouble").setup({
        use_diagnostic_signs = true,
        auto_jump = { "lsp_definitions", "lsp_references", "lsp_type_definitions", "lsp_implementations" },
        action_keys = {
          jump = { "<S-CR>" },
          jump_close = { "<CR>" },
        },
      })

      local keymap = require("config.keymap")

      keymap.normal.leader({
        d = {
          name = "Diagnostics",
          j = { vim.diagnostic.goto_next, "Next diagnostic" },
          k = { vim.diagnostic.goto_prev, "Previous diagnostic" },
          q = { ":TroubleToggle quickfix<cr>", "QuickFix" },
          l = { ":TroubleToggle loclist<cr>", "Locationlist" },
          t = { ":TroubleToggle telescope<cr>", "Telescope" },
          d = { ":TroubleToggle document_diagnostics<cr>", "Diagnostics" },
          w = { ":TroubleToggle workspace_diagnostics<cr>", "Workspace Diagnostics" },
        },
      })

      keymap.normal.register({
        ["]d"] = { vim.diagnostic.goto_next, "Next diagnostic" },
        ["[d"] = { vim.diagnostic.goto_prev, "Previous diagnostic" },
      })
    end,
  },
}
