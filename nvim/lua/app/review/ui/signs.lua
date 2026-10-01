local M = {}

M.ns = vim.api.nvim_create_namespace("review")

---@param bufnr integer
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
end

return M
