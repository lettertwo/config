-- Async git plumbing for the review app (uncommitted-review subset).
-- Staging, ranged-diff, and history helpers arrive with their owning milestones
-- (M2 stack, M5 staging).

local M = {}

---@param cwd string
---@param args string[]
---@param on_exit fun(result: {code: integer, stdout: string, stderr: string})
local function run(cwd, args, on_exit)
  vim.system(args, { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      on_exit({
        code = result.code,
        stdout = result.stdout or "",
        stderr = result.stderr or "",
      })
    end)
  end)
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

-- Fetch file content at a ref. "WORKTREE" reads from disk; anything else goes
-- through `git show ref:path`.
---@param cwd string
---@param ref string  git ref or "WORKTREE"
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
  run(cwd, { "git", "show", ref .. ":" .. path }, function(r)
    if r.code ~= 0 then
      callback(nil, r.stderr)
    else
      callback(r.stdout, nil)
    end
  end)
end

return M
