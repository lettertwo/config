-- Stack source: the review is sliced by a changeset unit. `combined` is one
-- cumulative changeset from the bottom node's base to the top node's head,
-- `branch` is one per stack node (Graphite branch or first-parent commit via
-- the graph fallback), and `commit` is one per first-parent commit. All are
-- base→head order, with the uncommitted changeset riding along when it has
-- files.

local M = {}
local git = require("app.review.diff.git")
local changesets = require("app.review.source.changesets")
local graph_factory = require("app.review.source.graph")
local uncommitted = require("app.review.source.uncommitted")

---@param opts {cwd: string, focus_branch?: string}  focus_branch defaults to
---                                                   the checked-out branch;
---                                                   the uncommitted layer
---                                                   only rides along when it
---                                                   IS the checked-out branch
---@return Review.Source
function M.new(opts)
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()

  local self = {
    kind = "stack",
    cwd = cwd,
    default_stack_order = "head-first", -- consumed by the outline's stack rendering
  }

  local current_branch = git.current_branch_sync(cwd)
  local focus_branch = opts.focus_branch or current_branch
  local include_uncommitted = focus_branch == current_branch
  local graph = graph_factory.create(cwd, focus_branch)
  -- The git-log fallback's nodes are already one per commit, so it has no
  -- separate branch unit: its commit unit is built from the node specs.
  local is_commit_graph = graph.is_commit_graph == true

  self.units = is_commit_graph and { "combined", "commit" } or { "combined", "branch", "commit" }
  self.default_unit = is_commit_graph and "commit" or "branch"

  local unit = self.default_unit
  function self:set_unit(new_unit)
    unit = new_unit
  end

  -- The last changesets.build result, handed back in as `prev` so a refresh
  -- reuses any changeset whose resolved shas didn't move. Persists across
  -- load()/refresh() calls (this source is reused for the docket's lifetime),
  -- unlike everything inside load_with_uncommitted, which is per-call.
  local prev_result = {}

  ---@param nodes Review.StackNode[]
  ---@return Review.ChangesetSpec[]
  local function branch_specs(nodes)
    local specs = {}
    for _, node in ipairs(nodes) do
      local meta = graph:metadata(node)
      table.insert(specs, {
        id = node.id,
        title = meta.title or node.branch or node.id,
        base = graph:base_ref(node),
        head = graph:head_ref(node),
        pr_number = meta.pr_number,
        current = node.id == focus_branch,
      })
    end
    return specs
  end

  -- One spec spanning the whole stack, bottom node's base to top node's
  -- head, regardless of focus. The id is a literal rather than a sha so the
  -- docket's position pin can't match a real commit's files on the fallback
  -- graph, and the stale/restack lookup (keyed by node id) never hits it.
  ---@param nodes Review.StackNode[]
  ---@return Review.ChangesetSpec[]
  local function combined_specs(nodes)
    if #nodes == 0 then
      return {}
    end
    local noun = is_commit_graph and "commits" or "branches"
    return {
      {
        id = "combined",
        title = ("Combined (%d %s)"):format(#nodes, noun),
        base = graph:base_ref(nodes[1]),
        head = graph:head_ref(nodes[#nodes]),
      },
    }
  end

  -- One spec per first-parent commit across every branch node, oldest to
  -- newest within a branch and branch order across the stack (base→head
  -- throughout, same as branch_specs). A commit's base chains to the
  -- next-older commit's sha, and the oldest commit's base to the branch's
  -- own base_ref — mirrors graph/git.lua's _build_nodes chaining, minus its
  -- zero-commit fallback nodes: a branch with no commits contributes
  -- nothing here. `callback` runs once, after every node's `git log` has
  -- answered (log_first_parent is per-branch async; nodes settle in any
  -- order, so specs are assembled only once all have).
  ---@param nodes Review.StackNode[]
  ---@param callback fun(specs: Review.ChangesetSpec[])
  local function commit_specs(nodes, callback)
    if #nodes == 0 then
      callback({})
      return
    end
    local per_node = {}
    local remaining = #nodes
    for ni, node in ipairs(nodes) do
      changesets.commit_specs(cwd, graph:base_ref(node), graph:head_ref(node), {}, function(list)
        per_node[ni] = list or {}
        remaining = remaining - 1
        if remaining == 0 then
          local specs = {}
          for i, n in ipairs(nodes) do
            for si, spec in ipairs(per_node[i]) do
              spec.branch = n.branch
              spec.current = n.id == focus_branch and si == #per_node[i]
              table.insert(specs, spec)
            end
          end
          callback(specs)
        end
      end)
    end
  end

  -- Adapt graph nodes to changesets.build's plain specs, one changeset per
  -- branch node, one per commit, or one for the whole stack, by unit. Streams:
  -- `callback` may run more than once, always with the full list in spec
  -- order (see changesets.build).
  ---@param nodes Review.StackNode[]
  ---@param callback fun(changesets: Review.Changeset[])
  local function build_changesets(nodes, callback)
    local function with_specs(specs)
      changesets.build(cwd, specs, prev_result, function(result)
        prev_result = result
        callback(result)
      end)
    end
    if unit == "combined" then
      with_specs(combined_specs(nodes))
    elseif unit == "commit" and not is_commit_graph then
      commit_specs(nodes, with_specs)
    else
      with_specs(branch_specs(nodes))
    end
  end

  ---@param nodes Review.StackNode[]
  ---@param callback fun(changesets: Review.Changeset[]?, err: string?)
  local function load_with_uncommitted(nodes, callback)
    -- The focus branch's position in the stack: uncommitted changes (when
    -- included) sit on top of ITS commits (not at the head of the whole
    -- stack), and the session opens focused here. Graphite node ids are
    -- branch names; the git fallback has no descendants, so its position is
    -- the tip.
    local cur_idx = nil
    for i, n in ipairs(nodes) do
      if n.id == focus_branch then
        cur_idx = i
      end
    end

    local stack_result, uncommitted_cs, stale = {}, nil, nil
    -- Which changeset is "current" (uncommitted, a stack node, or nothing)
    -- depends on facts each of these three only knows once it's answered at
    -- least once: whether the uncommitted layer has any files, where the
    -- focus branch sits among the (possibly skeleton) stack changesets, and
    -- whether any descendant is stale. Emitting before all three have
    -- answered at least once would let whichever settles first (each is a
    -- different number of git round trips) decide "current" by race. Once
    -- all three have answered, a stack changeset's OWN diff can keep
    -- streaming in — only the current-position decision needs this gate.
    local uncommitted_ready = not include_uncommitted
    local stack_ready, stale_ready = false, false

    -- Re-assembles the full changeset list from whatever's known so far and
    -- emits it. Called every time any of the three inputs above changes, so
    -- the docket sees a growing picture rather than waiting for every
    -- changeset's diff — just for the three answers above.
    local function emit()
      if not (uncommitted_ready and stack_ready and stale_ready) then
        return
      end
      local all = {}
      for _, cs in ipairs(stack_result) do
        -- stale keys are node (branch) ids and a commit spec's id is a sha
        -- (the combined spec's is a literal), so with the commit or combined
        -- unit on no header gets the restack mark; the mark describes a
        -- branch, and those headers don't stand for one.
        if stale and stale[cs.id] and cs.status == "ready" then
          -- A view, not a mutation: stack_result is also handed back to
          -- build_changesets as `prev` next time, and the raw title is what
          -- reuse's identity check (and any repeat emit) must see.
          table.insert(all, vim.tbl_extend("force", {}, cs, { title = cs.title .. " (needs restack)" }))
        else
          table.insert(all, cs)
        end
      end
      -- With the commit unit on, stack_result has more entries than nodes
      -- and cur_idx (a nodes-index) doesn't address it; each commit spec
      -- already carries its own `current` flag (set on the focus branch's
      -- newest commit by commit_specs), so find that position instead.
      local focus_idx = cur_idx
      if unit == "combined" then
        focus_idx = 1
      elseif unit == "commit" then
        focus_idx = nil
        for i, cs in ipairs(all) do
          if cs.current then
            focus_idx = i
          end
        end
      end
      if uncommitted_cs and #uncommitted_cs.files > 0 then
        -- stack_result may not have caught up to focus_idx yet (uncommitted
        -- is fetched first and can settle before it); clamp so an early
        -- emit inserts within bounds rather than erroring, and land at
        -- focus_idx's true position once the stack side has enough entries
        -- to hold it.
        local pos = math.min((focus_idx or #all) + 1, #all + 1)
        table.insert(all, pos, vim.tbl_extend("force", {}, uncommitted_cs, { current = true }))
      elseif focus_idx and all[focus_idx] then
        all[focus_idx] = vim.tbl_extend("force", {}, all[focus_idx], { current = true })
      elseif #all > 0 then
        all[#all] = vim.tbl_extend("force", {}, all[#all], { current = true })
      end
      callback(all, nil)
    end

    -- The user's own worktree changes are what they're most likely looking
    -- at; kick this off before the stack's own diffs so it isn't queued
    -- behind them on libuv's bounded threadpool. Only fetched when the focus
    -- branch is the checked-out one — a branch you aren't on has no worktree
    -- state of its own to show.
    if include_uncommitted then
      uncommitted.new({ cwd = cwd }):load(function(result, _)
        uncommitted_cs = result and result[1] or nil
        uncommitted_ready = true
        emit()
      end)
    end

    build_changesets(nodes, function(result)
      stack_result = result
      stack_ready = true
      emit()
    end)

    -- Descendants whose recorded parent_rev no longer matches the parent
    -- branch's actual head are pending a restack — their diffs describe
    -- pre-restack content, worth flagging rather than hiding.
    local descendants = {}
    if cur_idx then
      for i = cur_idx + 1, #nodes do
        table.insert(descendants, nodes[i])
      end
    end
    if #descendants == 0 then
      stale = {}
      stale_ready = true
      emit()
    else
      local refs = {}
      for _, n in ipairs(descendants) do
        table.insert(refs, "refs/heads/" .. n.parent_branch)
      end
      git.rev_parse_many(cwd, refs, function(shas)
        stale = {}
        for _, n in ipairs(descendants) do
          local sha = shas["refs/heads/" .. n.parent_branch]
          if sha and n.parent_rev ~= "" and sha ~= n.parent_rev then
            stale[n.id] = true
          end
        end
        stale_ready = true
        emit()
      end)
    end
  end

  function self:load(callback)
    if graph.load then
      graph:load(function(nodes, err)
        if err then
          callback(nil, err)
          return
        end
        load_with_uncommitted(nodes, callback)
      end)
    else
      load_with_uncommitted(graph:nodes(), callback)
    end
  end

  function self:refresh(callback)
    self:load(callback)
  end

  function self:can_stage()
    return true
  end

  return self
end

return M
