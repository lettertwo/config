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

local function node_for(row)
  return {
    id = row.branch,
    branch = row.branch,
    parent_branch = row.parent,
    head_rev = row.head_rev ~= "" and row.head_rev or row.branch,
    parent_rev = row.parent_rev ~= "" and row.parent_rev or (row.parent or "HEAD~1"),
  }
end

-- Walk the whole stack around the current branch: ancestors (via parent
-- links), the current branch, then descendants (via inverted child links,
-- depth-first with siblings sorted for determinism). Nodes come back in
-- base→head order with the current branch between its ancestors and
-- descendants. Cycle-guarded. Trunk gets a metadata row with an empty
-- parent_branch_name — stop there rather than emitting trunk as a changeset
-- with an empty base ref. Pure; exposed for unit tests.
---@param by_branch table<string, table>
---@param current string
---@return Review.StackNode[]
function M._walk(by_branch, current)
  -- On trunk itself (row with no parent — or no row at all, which is also
  -- how a gt-untracked branch looks), every stack in the repo is a
  -- "descendant" — that's not a reviewable stack. Return nothing and let the
  -- factory fall back to the git graph (upstream-commits semantics).
  local row0 = by_branch[current]
  if not row0 or not row0.parent or row0.parent == "" then
    return {}
  end

  local nodes = {}
  local visited = {}

  -- Ancestors + current, walking up.
  local branch = current
  while branch and by_branch[branch] and not visited[branch] do
    visited[branch] = true
    local row = by_branch[branch]
    if not row.parent or row.parent == "" then
      break
    end
    table.insert(nodes, 1, node_for(row))
    branch = row.parent
  end

  -- Descendants, walking down from current. Stacks are almost always linear;
  -- the rare fork flattens depth-first (M3's outline can render the tree).
  local children = {}
  for name, row in pairs(by_branch) do
    if row.parent and row.parent ~= "" then
      children[row.parent] = children[row.parent] or {}
      table.insert(children[row.parent], name)
    end
  end
  local function descend(from)
    local kids = children[from] or {}
    table.sort(kids)
    for _, kid in ipairs(kids) do
      if by_branch[kid] and not visited[kid] then
        visited[kid] = true
        table.insert(nodes, node_for(by_branch[kid]))
        descend(kid)
      end
    end
  end
  descend(current)

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
    -- node.head_rev is branch_revision from the metadata db — a snapshot
    -- taken at gt-time, so it's stale for plain-git commits (e.g. agent-
    -- authored). Resolve the live ref instead so head always reflects the
    -- branch's actual tip.
    return "refs/heads/" .. node.branch
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
