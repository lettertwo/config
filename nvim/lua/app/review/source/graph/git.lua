-- Git-log-backed stack graph fallback: one node per first-parent commit
-- between trunk and the current branch.

local M = {}
local git = require("app.review.diff.git")

-- Build nodes from a trunk/current pair and the (possibly nil/empty)
-- first-parent commit list, newest-first as git log returns them. Each
-- commit's base is the next-older commit; the oldest bases on trunk.
-- Nodes come back base→head (POC emitted newest-first here, opposite of the
-- graphite graph — standardized on graphite's base→head order).
-- Pure; exposed for unit tests.
---@param trunk string
---@param current string
---@param commits {sha: string, subject: string}[]?
---@return Review.StackNode[]
function M._build_nodes(trunk, current, commits)
  if current == trunk then
    -- On trunk: one degenerate node for HEAD
    return {
      {
        id = "HEAD",
        branch = current,
        parent_branch = trunk,
        head_rev = "HEAD",
        parent_rev = "HEAD~1",
        title = "HEAD",
      },
    }
  end
  if not commits or #commits == 0 then
    -- Treat the entire branch as one changeset vs trunk
    return {
      {
        id = current,
        branch = current,
        parent_branch = trunk,
        head_rev = current,
        parent_rev = trunk,
        title = current,
      },
    }
  end
  local nodes = {}
  for i = #commits, 1, -1 do
    local commit = commits[i]
    local parent = i < #commits and commits[i + 1].sha or trunk
    table.insert(nodes, {
      id = commit.sha,
      branch = commit.sha:sub(1, 8),
      parent_branch = parent,
      head_rev = commit.sha,
      parent_rev = parent,
      title = commit.subject,
    })
  end
  return nodes
end

---@param cwd string
---@return Review.StackGraph
function M.new(cwd)
  local self = {}
  local nodes = nil

  -- Async load: walk git log --first-parent from trunk to the current branch.
  function self:load(callback)
    git.trunk_branch(cwd, function(trunk)
      trunk = trunk or "main"
      local current = git.current_branch_sync(cwd)
      if current == trunk then
        nodes = M._build_nodes(trunk, current, nil)
        callback(nodes)
        return
      end
      git.log_first_parent(cwd, trunk, current, function(commits, err)
        nodes = M._build_nodes(trunk, current, not err and commits or nil)
        callback(nodes)
      end)
    end)
  end

  function self:nodes()
    return nodes or {}
  end

  function self:base_ref(node)
    return node.parent_rev
  end

  function self:head_ref(node)
    return node.head_rev
  end

  function self:metadata(node)
    return { title = node.title or node.branch }
  end

  return self
end

return M
