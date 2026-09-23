-- Shared stack walk: turns a branch -> {parent, head_rev, parent_rev} map
-- into an ordered Review.StackNode list, focused on one branch. Both the
-- Graphite and gh-stack providers reduce their own file formats to this map
-- shape and call in here.

local M = {}

local function node_for(row)
  return {
    id = row.branch,
    branch = row.branch,
    parent_branch = row.parent,
    head_rev = row.head_rev ~= "" and row.head_rev or row.branch,
    parent_rev = row.parent_rev ~= "" and row.parent_rev or (row.parent or "HEAD~1"),
  }
end

-- Walk the whole stack around one branch: ancestors (via parent links), the
-- branch itself, then descendants (via inverted child links, depth-first
-- with siblings sorted for determinism). Nodes come back in base→head order
-- with the focus branch between its ancestors and descendants. Cycle-
-- guarded. A branch with no row, or a row with no parent (trunk), yields
-- every other stack in the map as a "descendant" — that's not a reviewable
-- stack, so return nothing and let the caller fall through to the next
-- provider.
---@param by_branch table<string, table>
---@param branch string
---@return Review.StackNode[]
function M.walk(by_branch, branch)
  local row0 = by_branch[branch]
  if not row0 or not row0.parent or row0.parent == "" then
    return {}
  end

  local nodes = {}
  local visited = {}

  -- Ancestors + the focus branch, walking up.
  local cur = branch
  while cur and by_branch[cur] and not visited[cur] do
    visited[cur] = true
    local row = by_branch[cur]
    if not row.parent or row.parent == "" then
      break
    end
    table.insert(nodes, 1, node_for(row))
    cur = row.parent
  end

  -- Descendants, walking down from the focus branch. Stacks are almost
  -- always linear; the rare fork flattens depth-first.
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
  descend(branch)

  return nodes
end

return M
