-- Shared changeset builder: fans a list of {id, title, base, head, pr_number?}
-- specs out to `git.diff` and assembles Review.Changeset[] in spec order.
-- Extracted from the stack source so the ref source (base..head ranges) can
-- reuse the same fan-out/tagging/ordering behavior.
--
-- Streaming protocol: `callback` runs once with every slot Pending (or
-- reused Ready), then again each time a slot settles, always with the full
-- list in spec order. A caller that wants one final answer waits for a
-- snapshot with no Pending slot; single-spec callers (span.lua) do this.

local M = {}
local git = require("app.review.diff.git")
local parser = require("app.review.diff.parser")

---@class Review.ChangesetSpec
---@field id string
---@field title string
---@field base string
---@field head string
---@field pr_number? integer
---@field branch? string  commit-unit specs only: the owning branch, for the outline's header label
---@field current? boolean  fetch this spec's diff before its siblings (the
---                          changeset the caller expects to land on)

---@param spec Review.ChangesetSpec
---@param shas table<string, string?>
---@param status "pending"|"ready"|"failed"
---@param files Review.FileChange[]
---@param err string?
---@return Review.Changeset
local function make_slot(spec, shas, status, files, err)
  return {
    id = spec.id,
    title = spec.title,
    base_ref = spec.base,
    head_ref = spec.head,
    base_sha = shas[spec.base],
    head_sha = shas[spec.head],
    pr_number = spec.pr_number,
    branch = spec.branch,
    files = files,
    status = status,
    error = err,
  }
end

-- Diff each spec's base..head, tag every file with its changeset identity,
-- and stream changesets in spec order as each diff settles. A spec whose
-- resolved base/head shas match a Ready changeset in `prev` (same id) skips
-- the diff and reuses its files outright.
---@param cwd string
---@param specs Review.ChangesetSpec[]
---@param prev Review.Changeset[]?  changesets from the last build/refresh, for reuse
---@param callback fun(changesets: Review.Changeset[], err: string?)
function M.build(cwd, specs, prev, callback)
  if #specs == 0 then
    callback({}, nil)
    return
  end

  local prev_by_id = {}
  for _, cs in ipairs(prev or {}) do
    prev_by_id[cs.id] = cs
  end

  local refs = {}
  for _, spec in ipairs(specs) do
    table.insert(refs, spec.base)
    table.insert(refs, spec.head)
  end

  git.rev_parse_many(cwd, refs, function(shas)
    local slots = {}
    for i, spec in ipairs(specs) do
      local base_sha, head_sha = shas[spec.base], shas[spec.head]
      local reused = prev_by_id[spec.id]
      if reused and reused.status == "ready" and reused.base_sha == base_sha and reused.head_sha == head_sha then
        slots[i] = reused
      else
        slots[i] = make_slot(spec, shas, "pending", {})
      end
    end

    local function snapshot()
      local ordered = {}
      for i = 1, #specs do
        ordered[i] = slots[i]
      end
      callback(ordered, nil)
    end

    -- The skeleton: every slot Pending or reused Ready, before any diff runs.
    snapshot()

    -- Issue the current spec's diff before its siblings — first claim on
    -- libuv's bounded threadpool for the changeset the caller expects the
    -- user to land on first.
    local kickoff, current_i = {}, nil
    for i, spec in ipairs(specs) do
      if slots[i].status == "pending" then
        if spec.current and not current_i then
          current_i = i
        else
          table.insert(kickoff, i)
        end
      end
    end
    if current_i then
      table.insert(kickoff, 1, current_i)
    end

    for _, i in ipairs(kickoff) do
      local spec = specs[i]
      git.diff(cwd, spec.base, spec.head, function(raw, err)
        if err then
          slots[i] = make_slot(spec, shas, "failed", {}, err)
        else
          local files = parser.parse(raw or "")
          for _, f in ipairs(files) do
            f.changeset_id = spec.id
            f.base_ref = spec.base
            f.head_ref = spec.head
          end
          slots[i] = make_slot(spec, shas, "ready", files)
        end
        snapshot()
      end)
    end
  end)
end

-- One spec per first-parent commit in base..head, oldest to newest. By
-- default a commit's base chains to the next-older commit's sha and the
-- oldest commit's base is `base` itself, so the specs tile base..head
-- exactly (the stack source's shape). With `opts.parent_bases`, each commit
-- diffs against its own `sha^` (the empty tree for a root commit) instead,
-- which stays correct when `base` isn't a first-parent ancestor of `head`
-- (a 2-dot range across diverged branches). `callback` runs once; a failed
-- `git log` reports its error.
---@param cwd string
---@param base string
---@param head string
---@param opts {parent_bases?: boolean}
---@param callback fun(specs: Review.ChangesetSpec[]?, err: string?)
function M.commit_specs(cwd, base, head, opts, callback)
  git.log_first_parent(cwd, base, head, function(commits, err)
    if err then
      callback(nil, err)
      return
    end
    local function assemble(bases)
      local specs = {}
      for ci = #commits, 1, -1 do
        local commit = commits[ci]
        table.insert(specs, {
          id = commit.sha,
          title = commit.subject,
          base = bases and bases[commit.sha] or (ci < #commits and commits[ci + 1].sha or base),
          head = commit.sha,
        })
      end
      callback(specs, nil)
    end
    if not opts.parent_bases or #commits == 0 then
      assemble(nil)
      return
    end
    local refs = {}
    for _, commit in ipairs(commits) do
      table.insert(refs, commit.sha .. "^")
    end
    git.rev_parse_many(cwd, refs, function(shas)
      git.empty_tree(cwd, function(empty_sha)
        local bases = {}
        for _, commit in ipairs(commits) do
          bases[commit.sha] = shas[commit.sha .. "^"] or empty_sha
        end
        assemble(bases)
      end)
    end)
  end)
end

return M
