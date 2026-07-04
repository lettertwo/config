-- Serialized staging operations. Every op is a closure `fun(cb: fun(err?))`
-- run strictly one-at-a-time: git index writes race when keymaps repeat or
-- the index watcher fires mid-op, so the queue is the only writer.
--
-- Hunk ops reconstruct unified-diff patches from hunk.raw (parser.hunk_to_patch)
-- and pipe them to `git apply` — byte-fidelity, which is what fixed the POC's
-- pure-deletion "corrupt patch" bug. Line ops trim the patch to a selection
-- (parser.hunk_to_patch_lines); the reverse-applied ones build against the
-- NEW side, since that's the base they are undone from.

local git = require("app.review.diff.git")
local parser = require("app.review.diff.parser")

local M = {}

---@type {op: fun(cb: fun(err: string?)), on_done: fun()?, retried: boolean?}[]
local queue = {}

local dequeue

local function run(item)
  local done = false
  local function finish(err)
    if done then
      return
    end
    done = true
    -- index.lock contention: an external git process (editor plugin, file
    -- watcher, another terminal) holds the lock for a moment. Retry once
    -- before surfacing — the queue stays blocked meanwhile, keeping FIFO.
    if err and err:match("index%.lock") and not item.retried then
      item.retried = true
      vim.defer_fn(function()
        run(item)
      end, 100)
      return
    end
    if err then
      vim.notify("Staging error: " .. err, vim.log.levels.ERROR, { title = "Review" })
    end
    if item.on_done then
      vim.schedule(item.on_done)
    end
    table.remove(queue, 1)
    dequeue()
  end
  -- A synchronously-throwing op (e.g. vim.system ENOENT when git vanishes
  -- from PATH) would otherwise never invoke its callback and deadlock the
  -- queue for the rest of the session.
  local ok, err = pcall(item.op, finish)
  if not ok then
    finish(tostring(err))
  end
end

dequeue = function()
  local item = queue[1]
  if item then
    run(item)
  end
end

---@param op fun(cb: fun(err: string?))
---@param on_done fun()?
local function enqueue(op, on_done)
  table.insert(queue, { op = op, on_done = on_done })
  if #queue == 1 then
    dequeue()
  end
end

-- Exposed for tests: number of ops waiting or in flight.
function M._queue_len()
  return #queue
end

-- Exposed for tests: run through the queue machinery without git.
M._enqueue = enqueue

---@param cwd string
---@param path string
---@param on_done fun()?
function M.stage_file(cwd, path, on_done)
  enqueue(function(cb)
    git.stage_path(cwd, path, cb)
  end, on_done)
end

---@param cwd string
---@param path string
---@param on_done fun()?
function M.unstage_file(cwd, path, on_done)
  enqueue(function(cb)
    git.unstage_path(cwd, path, cb)
  end, on_done)
end

-- Stage or unstage a whole file by its LIVE index state, resolved when the
-- op runs: the enqueuer's FileChange snapshot can be stale behind an
-- in-flight op or refresh, and a wrong-direction toggle silently no-ops.
---@param cwd string
---@param path string
---@param on_done fun()?
function M.toggle_file(cwd, path, on_done)
  enqueue(function(cb)
    git.has_staged(cwd, path, function(staged)
      if staged then
        git.unstage_path(cwd, path, cb)
      else
        git.stage_path(cwd, path, cb)
      end
    end)
  end, on_done)
end

---@param cwd string
---@param path string
---@param on_done fun()?
function M.discard_file(cwd, path, on_done)
  enqueue(function(cb)
    git.discard_path(cwd, path, cb)
  end, on_done)
end

---@param cwd string
---@param path string
---@param on_done fun()?
function M.delete_untracked(cwd, path, on_done)
  enqueue(function(cb)
    git.delete_untracked(cwd, path, cb)
  end, on_done)
end

-- Stage one hunk of the unstaged (INDEX→WORKTREE) sub-file.
---@param cwd string
---@param file Review.FileChange
---@param hunk Review.Hunk
---@param on_done fun()?
function M.stage_hunk(cwd, file, hunk, on_done)
  local patch = parser.hunk_to_patch(file, hunk)
  enqueue(function(cb)
    git.apply_patch(cwd, patch, { cached = true }, cb)
  end, on_done)
end

-- Unstage one hunk of the staged_change (HEAD→INDEX) sub-file.
---@param cwd string
---@param file Review.FileChange
---@param hunk Review.Hunk
---@param on_done fun()?
function M.unstage_hunk(cwd, file, hunk, on_done)
  local patch = parser.hunk_to_patch(file, hunk)
  enqueue(function(cb)
    git.apply_patch(cwd, patch, { cached = true, reverse = true }, cb)
  end, on_done)
end

-- Discard one hunk of the unstaged (INDEX→WORKTREE) sub-file from the worktree.
---@param cwd string
---@param file Review.FileChange
---@param hunk Review.Hunk
---@param on_done fun()?
function M.discard_hunk(cwd, file, hunk, on_done)
  local patch = parser.hunk_to_patch(file, hunk)
  enqueue(function(cb)
    git.apply_patch(cwd, patch, { reverse = true }, cb)
  end, on_done)
end

-- Stage selected lines of one hunk of the unstaged (INDEX→WORKTREE) sub-file.
---@param cwd string
---@param file Review.FileChange
---@param hunk Review.Hunk
---@param keep_add fun(entry: Review.HunkLine): boolean
---@param keep_del fun(entry: Review.HunkLine): boolean
---@param on_done fun()?
function M.stage_lines(cwd, file, hunk, keep_add, keep_del, on_done)
  local patch = parser.hunk_to_patch_lines(file, hunk, keep_add, keep_del, "old")
  enqueue(function(cb)
    git.apply_patch(cwd, patch, { cached = true }, cb)
  end, on_done)
end

-- Unstage selected lines of one hunk of the staged_change (HEAD→INDEX) sub-file.
---@param cwd string
---@param file Review.FileChange
---@param hunk Review.Hunk
---@param keep_add fun(entry: Review.HunkLine): boolean
---@param keep_del fun(entry: Review.HunkLine): boolean
---@param on_done fun()?
function M.unstage_lines(cwd, file, hunk, keep_add, keep_del, on_done)
  local patch = parser.hunk_to_patch_lines(file, hunk, keep_add, keep_del, "new")
  enqueue(function(cb)
    git.apply_patch(cwd, patch, { cached = true, reverse = true }, cb)
  end, on_done)
end

-- Discard selected lines of one hunk of the unstaged (INDEX→WORKTREE)
-- sub-file from the worktree.
---@param cwd string
---@param file Review.FileChange
---@param hunk Review.Hunk
---@param keep_add fun(entry: Review.HunkLine): boolean
---@param keep_del fun(entry: Review.HunkLine): boolean
---@param on_done fun()?
function M.discard_lines(cwd, file, hunk, keep_add, keep_del, on_done)
  local patch = parser.hunk_to_patch_lines(file, hunk, keep_add, keep_del, "new")
  enqueue(function(cb)
    git.apply_patch(cwd, patch, { reverse = true }, cb)
  end, on_done)
end

-- Stage or unstage everything by the repo's LIVE status, resolved when the
-- op runs (same rationale as toggle_file): stage everything if anything is
-- unstaged, otherwise unstage everything.
---@param cwd string
---@param on_done fun()?
function M.toggle_all(cwd, on_done)
  enqueue(function(cb)
    git.has_unstaged(cwd, nil, function(has_unstaged)
      if has_unstaged then
        git.stage_all(cwd, cb)
      else
        git.unstage_all(cwd, cb)
      end
    end)
  end, on_done)
end

-- Stage or unstage a whole directory subtree by its LIVE state (same
-- toggle_file rationale): `git add -- <dir>` stages modifications,
-- deletions, and untracked files under the pathspec (git >= 2.0), so the
-- file-level primitives work verbatim scoped to a dir.
---@param cwd string
---@param dir string
---@param on_done fun()?
function M.toggle_tree(cwd, dir, on_done)
  enqueue(function(cb)
    git.has_unstaged(cwd, dir, function(has_unstaged)
      if has_unstaged then
        git.stage_path(cwd, dir, cb)
      else
        git.unstage_path(cwd, dir, cb)
      end
    end)
  end, on_done)
end

return M
