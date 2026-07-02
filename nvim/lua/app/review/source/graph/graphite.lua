-- Graphite-backed stack graph: reads branch metadata straight from
-- .git/.graphite_metadata.db via the sqlite3 CLI (never shells out to gt)
-- and PR info from .git/.graphite_pr_info. Synchronous — the one sqlite
-- query runs at construction time.

local M = {}
local git = require("app.review.diff.git")

-- Parse sqlite3's default |-separated output of
--   SELECT branch_name,parent_branch_name,branch_revision,parent_branch_revision
-- into a by-branch map. Pure; exposed for unit tests.
---@param stdout string
---@return table<string, {branch: string, parent: string, head_rev: string, parent_rev: string}>
function M._parse_metadata(stdout)
  local by_branch = {}
  for line in stdout:gmatch("[^\n]+") do
    local parts = vim.split(line, "|", { plain = true })
    if #parts >= 2 then
      by_branch[parts[1]] = {
        branch = parts[1],
        parent = parts[2],
        head_rev = parts[3] or "",
        parent_rev = parts[4] or "",
      }
    end
  end
  return by_branch
end

-- Walk up from the current branch through parent links, returning nodes in
-- base→head order. Cycle-guarded. Trunk gets a metadata row with an empty
-- parent_branch_name — stop there rather than emitting trunk as a changeset
-- with an empty base ref. Pure; exposed for unit tests.
---@param by_branch table<string, table>
---@param current string
---@return Review.StackNode[]
function M._walk(by_branch, current)
  local nodes = {}
  local visited = {}
  local branch = current
  while branch and by_branch[branch] and not visited[branch] do
    visited[branch] = true
    local row = by_branch[branch]
    if not row.parent or row.parent == "" then
      break
    end
    table.insert(nodes, 1, {
      id = branch,
      branch = branch,
      parent_branch = row.parent,
      head_rev = row.head_rev ~= "" and row.head_rev or branch,
      parent_rev = row.parent_rev ~= "" and row.parent_rev or (row.parent or "HEAD~1"),
    })
    branch = row.parent
  end
  return nodes
end

---@param cwd string
---@param common_dir? string  common git dir (resolved by the factory; falls
---                           back to resolving it here)
---@return Review.StackGraph
function M.new(cwd, common_dir)
  local self = {}
  common_dir = common_dir or git.common_dir_sync(cwd) or (cwd .. "/.git")
  local db_path = common_dir .. "/.graphite_metadata.db"
  local pr_info_path = common_dir .. "/.graphite_pr_info"

  -- Cached PR info (JSON), optional.
  local pr_map = {}
  if vim.fn.filereadable(pr_info_path) == 1 then
    local ok, data = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(pr_info_path), "\n"))
    end)
    if ok and data then
      for _, pr in ipairs(data.prInfos or {}) do
        if pr.headRefName then
          pr_map[pr.headRefName] = pr
        end
      end
    end
  end

  local r = vim.system({
    "sqlite3",
    db_path,
    "SELECT branch_name,parent_branch_name,branch_revision,parent_branch_revision FROM branch_metadata;",
  }, { text = true }):wait()
  local by_branch = M._parse_metadata(r.stdout or "")
  local nodes = M._walk(by_branch, git.current_branch_sync(cwd))

  function self:nodes()
    return nodes
  end

  function self:base_ref(node)
    return node.parent_rev
  end

  function self:head_ref(node)
    return node.head_rev
  end

  function self:metadata(node)
    local pr = pr_map[node.branch] or {}
    return {
      pr_number = pr.number,
      title = pr.title,
      body = pr.body,
    }
  end

  return self
end

return M
