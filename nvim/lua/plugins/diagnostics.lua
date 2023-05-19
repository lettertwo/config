local capcase = require("util").capcase

for key, icon in pairs(require("config").icons.diagnostics) do
  local name = "DiagnosticSign" .. capcase(key)
  vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
end

vim.diagnostic.config({
  update_in_insert = true,
  underline = true,
  severity_sort = true,
  virtual_text = true,
  virtual_lines = false,
  float = {
    focusable = false,
    close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
    style = "minimal",
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("Diagnostics", {}),
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_create_autocmd("CursorHold", {
      group = vim.api.nvim_create_augroup("Diagnostics" .. bufnr, {}),
      buffer = bufnr,
      callback = function()
        -- TODO: Make float show again if moved to another diagnostic on same line
        if line ~= vim.api.nvim_win_get_cursor(0)[1] then
          line = vim.api.nvim_win_get_cursor(0)[1]
          -- TODO: Make float for diagnostics show lsp_lines
          vim.diagnostic.open_float()
        end
      end,
    })
  end,
})

return {
  {
    "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    cmd = { "LspLinesToggle" },
    event = "VeryLazy",
    keys = {
      { "<leader>ud", "<cmd>LspLinesToggle<cr>", desc = "Toggle LSP Lines" },
      { "<leader>xL", "<cmd>LspLinesToggle<cr>", desc = "Toggle LSP Lines" },
    },
    config = function()
      require("lsp_lines").setup()
      vim.api.nvim_create_user_command("LspLinesToggle", function()
        vim.diagnostic.config({ virtual_text = not require("lsp_lines").toggle() })
      end, { desc = "Toggle LspLines" })
    end,
  },

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
      { "]x", vim.diagnostic.goto_next, desc = "Next diagnostic" },
      { "[x", vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
      { "<leader>xj", vim.diagnostic.goto_next, desc = "Next diagnostic" },
      { "<leader>xk", vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
      { "<leader>xx", "<cmd>TroubleToggle<cr>", desc = "Trouble: Show" },
      { "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", desc = "Trouble: Show QuickFix" },
      { "<leader>xl", "<cmd>TroubleToggle loclist<cr>", desc = "Trouble: Show Locationlist" },
      { "<leader>xt", "<cmd>TroubleToggle telescope<cr>", desc = "Trouble: Show Telescope" },
      { "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Trouble: Show Diagnostics" },
      { "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Trouble: Show Workspace Diagnostics" },
      { "<leader>xD", require("util").toggle_diagnostics, desc = "Toggle Diagnostics" },
      { "<leader>ux", require("util").toggle_diagnostics, desc = "Toggle Diagnostics" },
      { "<leader>xs", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Search Diagnostics" },
      { "<leader>sx", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Diagnostics" },
      { "<leader>xS", "<cmd>Telescope diagnostics<cr>", desc = "Search Workspace Diagnostics" },
      { "<leader>sX", "<cmd>Telescope diagnostics<cr>", desc = "Workspace Diagnostics" },
    },
  },
}
