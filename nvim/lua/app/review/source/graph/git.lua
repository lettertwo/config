-- Git-log-backed stack graph fallback: one node per first-parent commit
-- between trunk and the current branch.

local M = {}
local git = require("app.review.diff.git")

-- Build nodes from a base/current pair and the (possibly nil/empty)
-- first-parent commit list, newest-first as git log returns them. Each
-- commit's base is the next-older commit; the oldest bases on `base` (trunk
-- for a feature branch, the upstream ref for unpushed-on-trunk commits).
-- Nodes come back base→head (POC emitted newest-first here, opposite of the
-- graphite graph — standardized on graphite's base→head order).
-- Pure; exposed for unit tests.
---@param base string
---@param current string
---@param commits {sha: string, subject: string}[]?
---@return Review.StackNode[]
function M._build_nodes(base, current, commits)
  if not commits or #commits == 0 then
    if current == base then
      -- On trunk with nothing in flight: one courtesy node for the last
      -- commit, so the command never opens onto an empty session.
      return {
        {
          id = "HEAD",
          branch = current,
          parent_branch = base,
          head_rev = "HEAD",
          parent_rev = "HEAD~1",
          title = "HEAD",
        },
      }
    end
    -- Treat the entire branch as one changeset vs base
    return {
      {
        id = current,
        branch = current,
        parent_branch = base,
        head_rev = current,
        parent_rev = base,
        title = current,
      },
    }
  end
  local nodes = {}
  for i = #commits, 1, -1 do
    local commit = commits[i]
    local parent = i < #commits and commits[i + 1].sha or base
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

  -- Async load: walk git log --first-parent from the base to the current
  -- branch. Off trunk the base is trunk; on trunk the base is the upstream
  -- tracking ref, so unpushed commits show up as one changeset each ("what's
  -- in flight from this worktree").
  function self:load(callback)
    local function finish(base, commits)
      nodes = M._build_nodes(base, git.current_branch_sync(cwd), commits)
      callback(nodes)
    end
    git.trunk_branch(cwd, function(trunk)
      trunk = trunk or "main"
      local current = git.current_branch_sync(cwd)
      if current ~= trunk then
        git.log_first_parent(cwd, trunk, current, function(commits, err)
          finish(trunk, not err and commits or nil)
        end)
        return
      end
      git.upstream_ref(cwd, function(upstream)
        if not upstream then
          finish(trunk, nil)
          return
        end
        git.log_first_parent(cwd, upstream, "HEAD", function(commits, err)
          if err or not commits or #commits == 0 then
            finish(trunk, nil) -- fully pushed: courtesy last-commit node
          else
            finish(upstream, commits)
          end
        end)
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
