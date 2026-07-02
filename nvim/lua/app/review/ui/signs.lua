local M = {}

M.ns = vim.api.nvim_create_namespace("review")

-- M1 highlight groups only; staged variants arrive with M5 staging.
-- All default=true links so colorschemes can override.
function M.setup()
  local defs = {
    ReviewDiffAdd        = { link = "DiffAdd" },
    ReviewDiffDelete     = { link = "DiffDelete" },
    ReviewDiffAddWord    = { link = "DiffTextAdd" },
    ReviewDiffDeleteWord = { link = "DiffText" },
    ReviewDiffFiller     = { link = "DiffDelete" },
    ReviewSignAdd        = { link = "DiffAdd" },
    ReviewSignDelete     = { link = "DiffDelete" },
    ReviewSignChange     = { link = "DiffText" },
  }
  for name, opts in pairs(defs) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("keep", opts, { default = true }))
  end
end

---@param bufnr integer
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
end

return M
