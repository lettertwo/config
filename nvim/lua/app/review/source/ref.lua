-- Ref source: read-only review of a single commit/branch/tag (`<ref>^..<ref>`,
-- like `git show`) or a base..head range (per-commit changesets, reusing the
-- stack source's git-graph node builder). Never stages: can_stage() → false.
--
-- Asymmetry, deliberate: range reviews re-resolve base/head on every
-- refresh() (branch refs can move); single-ref reviews pin to the sha
-- resolved at load time, so a moving branch ref doesn't yank the diff out
-- from under the user mid-review.

local M = {}
local git = require("app.review.diff.git")
local changesets = require("app.review.source.changesets")
local graph_git = require("app.review.source.graph.git")

-- Pure; exposed for unit tests. Parses the `ref` argument into either a
-- single-ref or a range spec.
--   "" / nil        -> { kind = "single", ref = "HEAD" }
--   "foo"           -> { kind = "single", ref = "foo" }
--   "a..b"          -> { kind = "range", base = "a", head = "b" }
--   "a.."           -> { kind = "range", base = "a", head = "HEAD" }
--   "..b"           -> { kind = "range", base = "HEAD", head = "b" }
--   contains "..."  -> error (three-dot ranges aren't supported)
---@param arg string?
---@return {kind: "single", ref: string}|{kind: "range", base: string, head: string}|nil, string?
function M._parse_ref(arg)
  if arg and arg:find("...", 1, true) then
    return nil, "three-dot ranges are not supported; use base..head"
  end
  if not arg or arg == "" then
    return { kind = "single", ref = "HEAD" }
  end
  -- Refnames can't contain "..", so this pattern has no false positives.
  local base, head = arg:match("^(.-)%.%.(.*)$")
  if base then
    return {
      kind = "range",
      base = base ~= "" and base or "HEAD",
      head = head ~= "" and head or "HEAD",
    }
  end
  return { kind = "single", ref = arg }
end

-- Build the range changesets: resolve the first-parent commit list between
-- base and head, then either delegate to the stack graph's node builder (the
-- normal case) or — when base and head are the same commit — emit a single
-- empty-diff spec directly. `_build_nodes`'s empty-commit fallbacks (courtesy
-- HEAD node, whole-branch node) are stack semantics that don't apply here.
---@param cwd string
---@param base string
---@param head string
---@param callback fun(changesets: Review.Changeset[]?, err: string?)
local function load_range(cwd, base, head, callback)
  git.log_first_parent(cwd, base, head, function(commits, err)
    if err then
      callback(nil, err)
      return
    end
    if commits and #commits == 0 then
      git.rev_parse(cwd, base, function(base_sha, base_err)
        if base_err then
          callback(nil, "not a commit: " .. base)
          return
        end
        git.rev_parse(cwd, head, function(head_sha, head_err)
          if head_err then
            callback(nil, "not a commit: " .. head)
            return
          end
          changesets.build(cwd, {
            { id = head_sha, title = head, base = base_sha, head = head_sha },
          }, callback)
        end)
      end)
      return
    end

    local nodes = graph_git._build_nodes(base, head, commits)
    local specs = {}
    for _, node in ipairs(nodes) do
      table.insert(specs, {
        id = node.id,
        title = node.title or node.branch or node.id,
        base = node.parent_rev,
        head = node.head_rev,
      })
    end
    changesets.build(cwd, specs, callback)
  end)
end

-- Build the single-ref changeset: `<ref>^..<ref>`. Root commits (no parent)
-- fall back to the empty tree as base. Title comes from the resolved
-- commit's subject via a one-commit log_first_parent, falling back to the
-- ref string itself if that lookup comes up empty.
--
-- Comment the merge nuance: diffing a merge commit this way (`sha^..sha`)
-- shows only the first-parent diff, unlike `git show`'s combined format.
---@param cwd string
---@param ref string
---@param callback fun(changesets: Review.Changeset[]?, err: string?)
local function load_single(cwd, ref, callback)
  git.rev_parse(cwd, ref, function(sha, err)
    if err then
      callback(nil, "not a commit: " .. ref)
      return
    end

    local function build(base_sha)
      git.log_first_parent(cwd, base_sha, sha, function(commits)
        local title = (commits and commits[1] and commits[1].subject) or ref
        changesets.build(cwd, {
          { id = sha, title = title, base = base_sha, head = sha },
        }, callback)
      end)
    end

    git.rev_parse(cwd, sha .. "^", function(parent_sha, parent_err)
      if parent_err then
        -- Root commit: no parent to diff against.
        git.empty_tree(cwd, function(empty_sha)
          build(empty_sha)
        end)
      else
        build(parent_sha)
      end
    end)
  end)
end

---@param opts {cwd: string, ref: string?}
---@return Review.Source
function M.new(opts)
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()
  local ref = opts.ref

  local parsed, parse_err = M._parse_ref(ref)

  local self = {
    kind = "ref",
    cwd = cwd,
    default_outline_mode = parsed and parsed.kind == "range" and "stack" or "flat",
    default_stack_order = "base-first", -- review reads oldest -> newest
  }

  ---@param callback fun(changesets: Review.Changeset[]?, err: string?)
  function self:load(callback)
    if not parsed then
      callback(nil, parse_err)
      return
    end
    local function mark_current(changesets_result, load_err)
      if changesets_result and #changesets_result > 0 then
        changesets_result[1].current = true
      end
      callback(changesets_result, load_err)
    end
    if parsed.kind == "range" then
      load_range(cwd, parsed.base, parsed.head, mark_current)
    else
      load_single(cwd, parsed.ref, mark_current)
    end
  end

  -- Range reviews re-resolve base/head refs on refresh (they may have moved);
  -- single refs were already pinned to a sha at load, so re-running load is
  -- consistent for both — the asymmetry lives in what `parsed.ref`/`base`/
  -- `head` mean, not in this method.
  function self:refresh(callback)
    self:load(callback)
  end

  function self:can_stage()
    return false
  end

  return self
end

return M
