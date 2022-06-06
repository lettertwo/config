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

-- Set filetype to flowtype for .jsx? files with @flow pragma.
-- See plugins/treesitter.lua for more.
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  pattern = { "*.js", "*.jsx" },
  callback = function()
    if vim.fn.getline(1):match("//%s*@flow") then
      vim.api.nvim_command("setf flowtype")
    end
  end,
})
