-- Ref source: dispatches a classified argument by shape, over git.
--
-- A range (`a..b`/`a...b`, already classified) opens one changeset via
-- source/span.lua. A single token is ambiguous until git resolves it: a
-- local branch hands off to the stack source, focused there — the same
-- per-branch stack a bare `:Review` would open from that branch, with the
-- uncommitted layer riding along only when it's the checked-out branch. A
-- commit-ish (not a branch) opens one changeset, `parent..ref`; a root
-- commit diffs against the empty tree.
--
-- Range reviews re-resolve their endpoints on refresh() (branch refs can
-- move); single-ref reviews pin to the sha resolved at load time, so a
-- moving branch ref doesn't yank the diff out from under the user mid-review.

local M = {}
local git = require("app.review.diff.git")
local span = require("app.review.source.span")
local stack = require("app.review.source.stack")

-- Whether `name` is a local branch. Sync: this is resolution (post-classify,
-- pre-diff), not the classification step itself, and every other shape
-- decision the ref/stack sources make is already sync git.
---@param cwd string
---@param name string
---@return boolean
local function is_local_branch(cwd, name)
  local r = vim.system({ "git", "-C", cwd, "show-ref", "--verify", "--quiet", "refs/heads/" .. name }, {}):wait()
  return r.code == 0
end

-- Build the single-token changeset: `<ref>^..<ref>`, falling back to the
-- empty tree when ref is a root commit. Title comes from the resolved
-- commit's subject via a one-commit log_first_parent, falling back to the
-- ref string itself if that lookup comes up empty.
--
-- Diffing a merge commit this way (`sha^..sha`) shows only the first-parent
-- diff, unlike `git show`'s combined format.
---@param cwd string
---@param ref string
---@param callback fun(changesets: Review.Changeset[]?, err: string?)
local function load_commit(cwd, ref, callback)
  git.rev_parse(cwd, ref, function(sha, err)
    if err then
      callback(nil, "not a commit: " .. ref)
      return
    end

    local function build(base_sha)
      git.log_first_parent(cwd, base_sha, sha, function(commits)
        local title = (commits and commits[1] and commits[1].subject) or ref
        span.build_resolved(cwd, base_sha, sha, title, callback)
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

---@param opts {cwd: string, classified: table}  classified: source/classify.lua's "ref" result
---@return Review.Source
function M.new(opts)
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()
  local classified = opts.classified

  local self = {
    kind = "ref",
    cwd = cwd,
    default_outline_mode = "flat",
  }

  ---@param callback fun(changesets: Review.Changeset[]?, err: string?)
  function self:load(callback)
    local function mark_current(changesets_result, load_err)
      if changesets_result and #changesets_result > 0 then
        changesets_result[1].current = true
      end
      callback(changesets_result, load_err)
    end

    if classified.shape == "range" then
      if classified.dots == 3 then
        git.merge_base(cwd, classified.base, classified.head, function(base_sha, err)
          if err then
            callback(nil, err)
            return
          end
          span.build(cwd, base_sha, classified.head, classified.base .. "..." .. classified.head, mark_current)
        end)
      else
        span.build(cwd, classified.base, classified.head, classified.base .. ".." .. classified.head, mark_current)
      end
      return
    end

    -- Single token: a local branch delegates entirely to the stack source
    -- (this source object is only ever asked to load() once for that case).
    if is_local_branch(cwd, classified.ref) then
      self._delegate = stack.new({ cwd = cwd, focus_branch = classified.ref })
      self.default_outline_mode = self._delegate.default_outline_mode
      self.default_stack_order = self._delegate.default_stack_order
      self._delegate:load(callback)
      return
    end

    load_commit(cwd, classified.ref, mark_current)
  end

  function self:refresh(callback)
    if self._delegate then
      self._delegate:refresh(callback)
    else
      self:load(callback)
    end
  end

  function self:can_stage()
    return self._delegate ~= nil and self._delegate:can_stage()
  end

  return self
end

return M
