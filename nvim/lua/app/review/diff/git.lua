-- Async git plumbing for the review app: diffs, refs, and the staging write
-- primitives (M5).

local M = {}

---@param cwd string
---@param args string[]
---@param on_exit fun(result: {code: integer, stdout: string, stderr: string})
---@param stdin string?
local function run(cwd, args, on_exit, stdin)
  vim.system(args, { cwd = cwd, text = true, stdin = stdin }, function(result)
    vim.schedule(function()
      on_exit({
        code = result.code,
        stdout = result.stdout or "",
        stderr = result.stderr or "",
      })
    end)
  end)
end

-- ── Staging primitives ──────────────────────────────────────────────────────
-- All callbacks receive `err: string?` (nil on success). Serialization is the
-- staging queue's job (app.review.staging), not these primitives'.

-- `cond and nil or x` never yields nil (the and/or trap), so error mapping
-- is an explicit if.
local function err_of(r, fallback_err)
  if r.code == 0 then
    return nil
  end
  return r.stderr ~= "" and r.stderr or fallback_err
end

local function simple_op(args_fn, fallback_err)
  return function(cwd, path, callback)
    run(cwd, args_fn(path), function(r)
      callback(err_of(r, fallback_err))
    end)
  end
end

M.stage_path = simple_op(function(path)
  return { "git", "add", "--", path }
end, "git add failed")

M.unstage_path = simple_op(function(path)
  return { "git", "restore", "--staged", "--", path }
end, "git restore --staged failed")

M.discard_path = simple_op(function(path)
  return { "git", "restore", "--", path }
end, "git restore failed")

M.delete_untracked = simple_op(function(path)
  return { "git", "clean", "-f", "--", path }
end, "git clean failed")

-- Whether the index differs from HEAD for a path (any staged change,
-- including adds and deletions). code 1 = differences; 0 = none.
---@param cwd string
---@param path string
---@param callback fun(staged: boolean)
function M.has_staged(cwd, path, callback)
  run(cwd, { "git", "diff", "--cached", "--quiet", "--", path }, function(r)
    callback(r.code == 1)
  end)
end

-- Whether anything in the repo is unstaged: a worktree/index difference
-- (porcelain Y column non-blank) or an untracked file (Y column "?").
---@param cwd string
---@param callback fun(has_unstaged: boolean)
function M.has_unstaged(cwd, callback)
  run(cwd, { "git", "status", "--porcelain" }, function(r)
    for line in r.stdout:gmatch("[^\n]+") do
      if line:sub(2, 2) ~= " " then
        callback(true)
        return
      end
    end
    callback(false)
  end)
end

---@param cwd string
---@param callback fun(err: string?)
function M.stage_all(cwd, callback)
  run(cwd, { "git", "add", "-A" }, function(r)
    callback(err_of(r, "git add -A failed"))
  end)
end

---@param cwd string
---@param callback fun(err: string?)
function M.unstage_all(cwd, callback)
  run(cwd, { "git", "reset", "-q" }, function(r)
    callback(err_of(r, "git reset failed"))
  end)
end

-- Pipe a reconstructed patch to `git apply` on stdin.
---@param cwd string
---@param patch string
---@param opts {cached?: boolean, reverse?: boolean}
---@param callback fun(err: string?)
function M.apply_patch(cwd, patch, opts, callback)
  local args = { "git", "apply" }
  if opts.cached then
    table.insert(args, "--cached")
  end
  if opts.reverse then
    table.insert(args, "--reverse")
  end
  table.insert(args, "-")
  run(cwd, args, function(r)
    callback(err_of(r, "git apply failed"))
  end, patch)
end

-- Collect the three uncommitted diffs plus untracked files.
-- Untracked files are diffed individually via --no-index and appended to both
-- the combined and unstaged blobs; their "a/dev/null" headers are rewritten to
-- "a/<path>" so the parser attributes them to the right path.
---@param cwd string
---@param callback fun(combined: string, staged: string, unstaged_only: string, untracked: string[], err: string?)
function M.diff_uncommitted(cwd, callback)
  local combined_base, staged_out, unstaged_only_base
  local untracked_parts = {}
  local untracked_paths = {}
  local pending = 3

  local function join()
    pending = pending - 1
    if pending ~= 0 then
      return
    end
    -- Untracked blobs are appended in the final join (not per-pipeline) to
    -- avoid races between the three independent git invocations.
    local extra = table.concat(untracked_parts, "")
    callback(
      (combined_base or "") .. extra,
      staged_out or "",
      (unstaged_only_base or "") .. extra,
      untracked_paths,
      nil
    )
  end

  -- COMBINED: worktree vs HEAD. The untracked fan-out is chained inside this
  -- callback so untracked_parts are fully populated before join() fires.
  run(cwd, { "git", "diff", "--no-color", "--unified=3", "HEAD" }, function(r)
    combined_base = r.stdout
    run(cwd, { "git", "ls-files", "--others", "--exclude-standard" }, function(lr)
      local paths = {}
      for path in (lr.stdout or ""):gmatch("[^\n]+") do
        table.insert(paths, path)
      end
      untracked_paths = paths
      if #paths == 0 then
        join()
        return
      end
      local upending = #paths
      for i, path in ipairs(paths) do
        run(cwd, { "git", "diff", "--no-color", "--unified=3", "--no-index", "--", "/dev/null", path }, function(ur)
          local fixed = ur.stdout:gsub("diff %-%-git a/dev/null b/([^\n]+)", function(p)
            return "diff --git a/" .. p .. " b/" .. p
          end)
          untracked_parts[i] = fixed
          upending = upending - 1
          if upending == 0 then
            join()
          end
        end)
      end
    end)
  end)

  -- STAGED: index vs HEAD
  run(cwd, { "git", "diff", "--no-color", "--unified=3", "--cached", "HEAD" }, function(r)
    staged_out = r.stdout
    join()
  end)

  -- UNSTAGED_ONLY: worktree vs index
  run(cwd, { "git", "diff", "--no-color", "--unified=3" }, function(r)
    unstaged_only_base = r.stdout
    join()
  end)
end

-- Ranged diff between two refs. head omitted when nil or "WORKTREE"
-- (worktree vs base). git diff exits nonzero with output for some warnings,
-- so only report an error when there is also no stdout.
---@param cwd string
---@param base string
---@param head string?
---@param callback fun(diff: string?, err: string?)
function M.diff(cwd, base, head, callback)
  local args = { "git", "diff", "--no-color", "--unified=3", base }
  if head and head ~= "WORKTREE" then
    table.insert(args, head)
  end
  run(cwd, args, function(r)
    if r.code ~= 0 and r.stdout == "" then
      callback(nil, r.stderr)
    else
      callback(r.stdout, nil)
    end
  end)
end

-- Resolve the common git dir (shared across worktrees). In a linked worktree
-- cwd/.git is a file pointing at <common>/worktrees/<name>, so anything that
-- lives repo-wide (e.g. graphite metadata) must be looked up here, never via
-- a literal cwd .. "/.git" path. Relative output (plain repos return ".git")
-- is normalized against cwd.
---@param cwd string
---@return string?
function M.common_dir_sync(cwd)
  local r = vim.system({ "git", "-C", cwd, "rev-parse", "--git-common-dir" }, { text = true }):wait()
  if r.code ~= 0 then
    return nil
  end
  local dir = vim.trim(r.stdout or "")
  if dir == "" then
    return nil
  end
  if not dir:match("^/") then
    dir = cwd .. "/" .. dir
  end
  return dir
end

-- Resolve this checkout's own git dir (per-worktree — the index lives here,
-- unlike the graphite metadata which lives in the common dir).
---@param cwd string
---@param callback fun(dir: string?)
function M.git_dir(cwd, callback)
  run(cwd, { "git", "rev-parse", "--git-dir" }, function(r)
    if r.code ~= 0 then
      callback(nil)
      return
    end
    local dir = vim.trim(r.stdout)
    if dir == "" then
      callback(nil)
    elseif dir:match("^/") then
      callback(dir)
    else
      callback(cwd .. "/" .. dir)
    end
  end)
end

---@param cwd string
---@return string
function M.current_branch_sync(cwd)
  local r = vim.system({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }):wait()
  return vim.trim(r.stdout or "HEAD")
end

---@param cwd string
---@param callback fun(branch: string?, err: string?)
function M.trunk_branch(cwd, callback)
  run(cwd, { "git", "rev-parse", "--abbrev-ref", "origin/HEAD" }, function(r)
    if r.code == 0 then
      local branch = vim.trim(r.stdout):gsub("^origin/", "")
      callback(branch, nil)
    else
      run(cwd, { "git", "show-ref", "--verify", "--quiet", "refs/heads/main" }, function(r2)
        callback(r2.code == 0 and "main" or "master", nil)
      end)
    end
  end)
end

-- The current branch's upstream tracking ref (e.g. "origin/main"), or nil
-- when none is configured.
---@param cwd string
---@param callback fun(upstream: string?)
function M.upstream_ref(cwd, callback)
  run(cwd, { "git", "rev-parse", "--abbrev-ref", "@{upstream}" }, function(r)
    if r.code ~= 0 then
      callback(nil)
      return
    end
    local ref = vim.trim(r.stdout)
    callback(ref ~= "" and ref or nil)
  end)
end

---@param cwd string
---@param base string
---@param head string
---@param callback fun(commits: {sha: string, subject: string}[]?, err: string?)
function M.log_first_parent(cwd, base, head, callback)
  run(cwd, { "git", "log", "--first-parent", "--format=%H %s", base .. ".." .. head }, function(r)
    if r.code ~= 0 then
      callback(nil, r.stderr)
      return
    end
    local commits = {}
    for line in r.stdout:gmatch("[^\n]+") do
      local sha, subject = line:match("^(%x+) (.*)$")
      if sha then
        table.insert(commits, { sha = sha, subject = subject })
      end
    end
    callback(commits, nil)
  end)
end

---@param cwd string
---@param callback fun(sha: string?, err: string?)
function M.head_sha(cwd, callback)
  run(cwd, { "git", "rev-parse", "HEAD" }, function(r)
    if r.code ~= 0 then
      callback(nil, r.stderr)
    else
      callback(vim.trim(r.stdout), nil)
    end
  end)
end

-- Fetch file content at a ref. "WORKTREE" reads from disk; "INDEX" reads the
-- staged blob (`git show :path` — the index entry is keyed by the NEW path);
-- anything else goes through `git show ref:path`.
---@param cwd string
---@param ref string  git ref, "WORKTREE", or "INDEX"
---@param path string
---@param callback fun(content: string?, err: string?)
function M.show(cwd, ref, path, callback)
  if ref == "WORKTREE" then
    local full = cwd .. "/" .. path
    if vim.fn.filereadable(full) == 1 then
      callback(table.concat(vim.fn.readfile(full), "\n"), nil)
    else
      callback(nil, "unreadable: " .. full)
    end
    return
  end
  if ref == "INDEX" then
    ref = ""
  end
  run(cwd, { "git", "show", ref .. ":" .. path }, function(r)
    if r.code ~= 0 then
      callback(nil, r.stderr)
    else
      callback(r.stdout, nil)
    end
  end)
end

return M
