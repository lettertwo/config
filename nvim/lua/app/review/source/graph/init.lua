-- StackGraph interface and factory.
-- Prefer Graphite when .graphite_metadata.db is present; fall back to git log.

---@class Review.StackGraph
---@field nodes fun(self: Review.StackGraph): Review.StackNode[]
---@field load? fun(self: Review.StackGraph, callback: fun(nodes: Review.StackNode[]))
---@field base_ref fun(self: Review.StackGraph, node: Review.StackNode): string
---@field head_ref fun(self: Review.StackGraph, node: Review.StackNode): string
---@field metadata fun(self: Review.StackGraph, node: Review.StackNode): {pr_number?: integer, title?: string, body?: string}

---@class Review.StackNode
---@field id string
---@field branch string
---@field parent_branch? string
---@field head_rev string
---@field parent_rev string
---@field title? string

local M = {}

---@param cwd string
---@return Review.StackGraph
function M.create(cwd)
  local db_path = cwd .. "/.git/.graphite_metadata.db"
  if vim.fn.filereadable(db_path) == 1 and vim.fn.executable("sqlite3") == 1 then
    local ok, graphite = pcall(require, "app.review.source.graph.graphite")
    if ok then
      return graphite.new(cwd)
    end
  end
  return require("app.review.source.graph.git").new(cwd)
end

return M
