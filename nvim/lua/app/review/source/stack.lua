-- Stack source: one changeset per stack node (Graphite branch or first-parent
-- commit via the graph fallback), base→head order, with the uncommitted
-- changeset prepended when it has files.

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
    default_outline_mode = "stack", -- consumed by the M3 outline
    default_stack_order = "head-first", -- consumed by the outline's stack rendering
  }

  local current_branch = git.current_branch_sync(cwd)
  local focus_branch = opts.focus_branch or current_branch
  local include_uncommitted = focus_branch == current_branch
  local graph = graph_factory.create(cwd, focus_branch)

  -- The last changesets.build result, handed back in as `prev` so a refresh
  -- reuses any changeset whose resolved shas didn't move. Persists across
  -- load()/refresh() calls (this source is reused for the docket's lifetime),
  -- unlike everything inside load_with_uncommitted, which is per-call.
  local prev_result = {}

  -- Adapt graph nodes to changesets.build's plain specs via the graph's own
  -- base_ref/head_ref/metadata accessors (Graphite db or git-log fallback).
  -- Streams: `callback` may run more than once, always with the full list in
  -- spec order (see changesets.build).
  ---@param nodes Review.StackNode[]
  ---@param callback fun(changesets: Review.Changeset[])
  local function build_changesets(nodes, callback)
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
    changesets.build(cwd, specs, prev_result, function(result)
      prev_result = result
      callback(result)
    end)
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
        if stale and stale[cs.id] and cs.status == "ready" then
          -- A view, not a mutation: stack_result is also handed back to
          -- build_changesets as `prev` next time, and the raw title is what
          -- reuse's identity check (and any repeat emit) must see.
          table.insert(all, vim.tbl_extend("force", {}, cs, { title = cs.title .. " (needs restack)" }))
        else
          table.insert(all, cs)
        end
      end
      if uncommitted_cs and #uncommitted_cs.files > 0 then
        -- stack_result may not have caught up to cur_idx yet (uncommitted is
        -- fetched first and can settle before it); clamp so an early emit
        -- inserts within bounds rather than erroring, and land at cur_idx's
        -- true position once the stack side has enough entries to hold it.
        local pos = math.min((cur_idx or #all) + 1, #all + 1)
        table.insert(all, pos, vim.tbl_extend("force", {}, uncommitted_cs, { current = true }))
      elseif cur_idx and all[cur_idx] then
        all[cur_idx] = vim.tbl_extend("force", {}, all[cur_idx], { current = true })
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
