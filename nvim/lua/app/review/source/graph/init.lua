-- StackGraph interface and factory.
-- Precedence per focus branch: gh-stack, then Graphite, then git log. Each
-- provider answers only for a branch it actually tracks (non-empty walk);
-- a branch tracked by both gh-stack and Graphite goes to gh-stack.

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
---@param branch? string  focus branch (defaults to the checked-out branch)
---@return Review.StackGraph
function M.create(cwd, branch)
  -- Graphite and gh-stack state both key off the common git dir — shared
  -- across worktrees (bare-repo + worktree layouts have no cwd/.git
  -- directory at all).
  local common = require("app.review.diff.git").common_dir_sync(cwd)

  local ok_gh, gh_stack = pcall(require, "app.review.source.graph.gh_stack")
  if ok_gh then
    local g = gh_stack.new(cwd, common, branch)
    -- An empty walk means this branch is untracked by gh-stack (or a
    -- link-managed stack, which leaves no local file) — not an empty stack.
    if #g:nodes() > 0 then
      return g
    end
  end

  local db_path = common and (common .. "/.graphite_metadata.db")
  if db_path and vim.fn.filereadable(db_path) == 1 and vim.fn.executable("sqlite3") == 1 then
    local ok, graphite = pcall(require, "app.review.source.graph.graphite")
    if ok then
      local g = graphite.new(cwd, common, branch)
      -- A db can exist while the branch is untracked by gt (or the db is
      -- vestigial with an empty branch_metadata table) — an empty walk means
      -- graphite has nothing to say here, not that the stack is empty.
      if #g:nodes() > 0 then
        return g
      end
    end
  end
  return require("app.review.source.graph.git").new(cwd)
end

return M
