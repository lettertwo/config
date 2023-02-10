local capcase = require("util").capcase

for key, icon in pairs(require("config").icons.diagnostics) do
  local name = "DiagnosticSign" .. capcase(key)
  vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
end

vim.diagnostic.config({
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
  -- better diagnostics list and others
  {
    "folke/trouble.nvim",
    cmd = { "TroubleToggle", "Trouble" },
    opts = {
      use_diagnostic_signs = true,
      auto_jump = { "lsp_definitions", "lsp_references", "lsp_type_definitions", "lsp_implementations" },
      action_keys = {
        jump = { "<S-CR>" },
        jump_close = { "<CR>" },
      },
    },
    keys = {
      { "]d", vim.diagnostic.goto_next, desc = "Next diagnostic" },
      { "[d", vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
      { "<leader>xj", vim.diagnostic.goto_next, desc = "Next diagnostic" },
      { "<leader>xk", vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
      { "<leader>xx", ":TroubleToggle<cr>", desc = "Trouble" },
      { "<leader>xq", ":TroubleToggle quickfix<cr>", desc = "QuickFix" },
      { "<leader>xl", ":TroubleToggle loclist<cr>", desc = "Locationlist" },
      { "<leader>xt", ":TroubleToggle telescope<cr>", desc = "Telescope" },
      { "<leader>xd", ":TroubleToggle document_diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>xw", ":TroubleToggle workspace_diagnostics<cr>", desc = "Workspace Diagnostics" },
    },
  },
}
