-- One-changeset diff builder: resolves two endpoints to shas and hands a
-- single spec to the shared fan-out in source/changesets.lua. Used for a
-- `base..head` or `base...head` argument and for a single commit-ish
-- reviewed as `parent..ref`.

local M = {}
local git = require("app.review.diff.git")
local changesets = require("app.review.source.changesets")

-- Build from shas (or the empty-tree hash) already known good — no
-- revalidation, since the empty tree isn't a commit and would fail the
-- commit-ish check below.
--
-- changesets.build streams (a Pending skeleton, then the settled slot); this
-- source stays single-shot, so the skeleton is swallowed and a Failed slot's
-- error is surfaced the way every other failure here is — closing the tab,
-- not a stack header mark (there's no stack).
---@param cwd string
---@param base_sha string
---@param head_sha string
---@param title string
---@param callback fun(changesets: Review.Changeset[]?, err: string?)
function M.build_resolved(cwd, base_sha, head_sha, title, callback)
  changesets.build(cwd, {
    { id = head_sha, title = title, base = base_sha, head = head_sha },
  }, nil, function(result, err)
    if err then
      callback(nil, err)
      return
    end
    local cs = result[1]
    if not cs or cs.status == "pending" then
      return
    end
    if cs.status == "failed" then
      callback(nil, cs.error)
      return
    end
    callback(result, nil)
  end)
end

-- Build from ref text, validating both endpoints resolve to a commit first
-- so a bad endpoint fails with a clean message before any diff runs.
---@param cwd string
---@param base string
---@param head string
---@param title string
---@param callback fun(changesets: Review.Changeset[]?, err: string?)
function M.build(cwd, base, head, title, callback)
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
      M.build_resolved(cwd, base_sha, head_sha, title, callback)
    end)
  end)
end

return M
