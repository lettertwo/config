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
  update_in_insert = false,
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

require("trouble").setup({
  use_diagnostic_signs = true,
})

require("keymap").normal.leader({
  d = {
    name = "Diagnostics",
    j = { ":lua vim.diagnostic.goto_next({buffer=0})<CR>", "Jump to next diagnostic" },
    k = { ":lua vim.diagnostic.goto_prev({buffer=0})<CR>", "Jump to previous diagnostic" },
    q = { ":Trouble quickfix<cr>", "QuickFix" },
    l = { ":Trouble loclist<cr>", "Locationlist" },
    t = { ":Trouble telescope<cr>", "Telescope" },
    d = { ":Trouble document_diagnostics<cr>", "Diagnostics" },
    w = { ":Trouble workspace_diagnostics<cr>", "Workspace Diagnostics" },
  },
})

local function hover()
  if vim.lsp.buf.is_active and vim.lsp.buf.is_active() then
    vim.lsp.buf.signature()
  else
    vim.diagnostic.open_float()
  end
end

local function setup_buffer()
  local bufnr = vim.api.nvim_buf_get_number(0)
  local buf_group = vim.api.nvim_create_augroup("lsp_hover_" .. bufnr, { clear = true })
  -- Show diagnostic on hover
  vim.api.nvim_create_autocmd("CursorHold", { buffer = bufnr, group = buf_group, callback = hover })
end

local group = vim.api.nvim_create_augroup("diagnostics", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", { group = group, callback = setup_buffer })
