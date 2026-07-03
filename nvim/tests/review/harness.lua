-- Shared harness for the headless review-app e2e scenarios: check/finish
-- output format, fixture builders, and the small polling helpers every
-- scenario in scenarios/ relies on. See e2e.lua for the dispatcher.

local M = {}

M.scenario = vim.env.REVIEW_E2E or "standalone"

local failed = false

function M.check(name, ok, detail)
  if not ok then
    failed = true
  end
  io.stdout:write(string.format(
    "%s [%s] %s%s\n",
    ok and "PASS" or "FAIL",
    M.scenario,
    name,
    detail and (" — " .. tostring(detail)) or ""
  ))
end

function M.failed()
  return failed
end

function M.finish()
  io.stdout:write(string.format("E2E-RESULT [%s]: %s\n", M.scenario, failed and "FAIL" or "PASS"))
  vim.cmd(failed and "cquit 1" or "silent! qa!")
end

-- ── Fixture repos ───────────────────────────────────────────────────────────

-- main.lua: staged edit (fn_2), unstaged edit (fn_9, asymmetric), line 1
-- deleted (row-0 virt_lines case). gone.lua deleted, untracked.lua untracked.
function M.build_fixture()
  local cwd = vim.fn.tempname()
  vim.fn.mkdir(cwd, "p")
  local function git(...)
    local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
    assert(r.code == 0, r.stderr)
  end
  git("init", "-q")
  git("config", "user.email", "t@t")
  git("config", "user.name", "t")

  local main = { "-- header comment line 1" }
  for i = 1, 14 do
    vim.list_extend(main, { ("local function fn_%d()"):format(i), ("  return %d + %d"):format(i, i), "end", "" })
  end
  vim.fn.writefile(main, cwd .. "/main.lua")
  vim.fn.writefile({ "local gone = true", "return gone" }, cwd .. "/gone.lua")
  git("add", ".")
  git("commit", "-qm", "init")

  -- staged: drop line 1, edit fn_2
  table.remove(main, 1)
  for i, l in ipairs(main) do
    main[i] = l:gsub("return 2 %+ 2", "return 2 * 2 -- staged edit")
  end
  vim.fn.writefile(main, cwd .. "/main.lua")
  git("add", "main.lua")
  -- unstaged on top: asymmetric change in fn_9
  for i, l in ipairs(main) do
    main[i] = l:gsub("return 9 %+ 9", "return compute_nine(9, 9) -- unstaged")
  end
  vim.fn.writefile(main, cwd .. "/main.lua")
  git("rm", "-q", "gone.lua")
  vim.fn.writefile({ "local fresh = 1", "print(fresh)" }, cwd .. "/untracked.lua")
  return cwd
end

-- Stack fixture: main with a base commit, feature branch with two commits,
-- plus an uncommitted edit. Exercises the git-fallback graph (no graphite db).
function M.build_stack_fixture()
  local cwd = vim.fn.tempname()
  vim.fn.mkdir(cwd, "p")
  local function git(...)
    local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
    assert(r.code == 0, r.stderr)
  end
  git("init", "-q")
  git("branch", "-M", "main")
  git("config", "user.email", "t@t")
  git("config", "user.name", "t")

  vim.fn.writefile({ "local base = 1", "return base" }, cwd .. "/base.lua")
  git("add", ".")
  git("commit", "-qm", "init")
  git("checkout", "-qb", "feature")
  vim.fn.writefile({ "local a1 = 1", "return a1" }, cwd .. "/a1.lua")
  git("add", ".")
  git("commit", "-qm", "add a1")
  vim.fn.writefile({ "local b1 = 1", "return b1" }, cwd .. "/b1.lua")
  git("add", ".")
  git("commit", "-qm", "add b1")
  vim.fn.writefile({ "local base = 2 -- dirty", "return base" }, cwd .. "/base.lua")
  return cwd
end

-- Trunk-ahead fixture: on main with an upstream, two unpushed commits, and a
-- dirty worktree. "review stack" here should show what's in flight, not just
-- the last commit.
function M.build_trunk_ahead_fixture()
  local cwd = vim.fn.tempname()
  vim.fn.mkdir(cwd, "p")
  local function git(...)
    local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
    assert(r.code == 0, r.stderr)
  end
  git("init", "-q")
  git("branch", "-M", "main")
  git("config", "user.email", "t@t")
  git("config", "user.name", "t")
  vim.fn.writefile({ "local base = 1" }, cwd .. "/base.lua")
  git("add", ".")
  git("commit", "-qm", "init")
  local origin = vim.fn.tempname()
  local r = vim.system({ "git", "clone", "-q", "--bare", cwd, origin }, { text = true }):wait()
  assert(r.code == 0, r.stderr)
  git("remote", "add", "origin", origin)
  git("fetch", "-q", "origin")
  git("branch", "-q", "--set-upstream-to=origin/main", "main")
  -- Two unpushed commits + a dirty file.
  vim.fn.writefile({ "local a1 = 1" }, cwd .. "/a1.lua")
  git("add", ".")
  git("commit", "-qm", "unpushed one")
  vim.fn.writefile({ "local b1 = 1" }, cwd .. "/b1.lua")
  git("add", ".")
  git("commit", "-qm", "unpushed two")
  vim.fn.writefile({ "local base = 2 -- dirty" }, cwd .. "/base.lua")
  return cwd
end

-- ── Polling helpers ──────────────────────────────────────────────────────────

function M.feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

-- The outline picker takes focus when the review opens, so scenarios locate
-- and drive the diff window explicitly rather than assuming it is current.
function M.diff_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.api.nvim_buf_get_name(b):match("review://") then
      return w, b
    end
  end
end

function M.focus_diff()
  local w, b = M.diff_win()
  if w then
    vim.api.nvim_set_current_win(w)
  end
  return w, b
end

function M.diff_line1()
  local _, b = M.diff_win()
  if not b then
    return ""
  end
  return vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] or ""
end

function M.wait_line1(pat)
  return vim.wait(8000, function()
    local l = M.diff_line1()
    return l ~= "" and not l:match("^Loading") and (not pat or l:match(pat) ~= nil)
  end, 50)
end

-- The review outline picker, once its finder has produced items.
function M.wait_outline(min_items)
  local picker
  vim.wait(8000, function()
    local pickers = _G.Snacks and Snacks.picker and Snacks.picker.get() or {}
    picker = pickers[1]
    return picker ~= nil and picker:count() >= (min_items or 1)
  end, 50)
  return picker
end

return M
