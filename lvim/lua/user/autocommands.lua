vim.api.nvim_create_autocmd("InsertEnter", { pattern = { "*" }, command = ":set norelativenumber" })
vim.api.nvim_create_autocmd("InsertLeave", { pattern = { "*" }, command = ":set relativenumber" })
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*/lua/user/*.lua,*'lua/user/*/*.lua" },
  command = ':lua require("user").reload(vim.fn.expand("<afile>"))',
})
vim.api.nvim_create_autocmd(
  "CursorHold",
  { pattern = { "*" }, command = ':lua vim.diagnostic.open_float({scope="line"})' }
)
