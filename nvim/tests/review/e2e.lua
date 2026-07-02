-- Headless end-to-end checks for the review app. Run via tests/review/run.fish,
-- or directly:
--
--   VIM_APP=review REVIEW_E2E=standalone nvim --headless -c "lua dofile('nvim/tests/review/e2e.lua')"
--   VIM_APP=review REVIEW_E2E=degraded   nvim --headless -c "lua dofile('nvim/tests/review/e2e.lua')"
--                  REVIEW_E2E=embedded   nvim --headless -c "lua dofile('nvim/tests/review/e2e.lua')"
--
-- Each scenario needs its own nvim process (degraded stubs the codediff
-- require before anything loads it; embedded boots the default app).
-- Prints PASS/FAIL per check and a final E2E-RESULT line; exits 1 on failure.

local scenario = vim.env.REVIEW_E2E or "standalone"

local failed = false
local function check(name, ok, detail)
  if not ok then
    failed = true
  end
  io.stdout:write(string.format(
    "%s [%s] %s%s\n",
    ok and "PASS" or "FAIL",
    scenario,
    name,
    detail and (" — " .. tostring(detail)) or ""
  ))
end

local function finish()
  io.stdout:write(string.format("E2E-RESULT [%s]: %s\n", scenario, failed and "FAIL" or "PASS"))
  vim.cmd(failed and "cquit 1" or "silent! qa!")
end

-- ── Fixture repo ────────────────────────────────────────────────────────────
-- main.lua: staged edit (fn_2), unstaged edit (fn_9, asymmetric), line 1
-- deleted (row-0 virt_lines case). gone.lua deleted, untracked.lua untracked.
local function build_fixture()
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
local function build_stack_fixture()
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

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

local function wait_line1(pat)
  return vim.wait(8000, function()
    local l = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
    return l ~= "" and not l:match("^Loading") and (not pat or l:match(pat) ~= nil)
  end, 50)
end

local fixture = scenario == "stack" and build_stack_fixture() or build_fixture()
vim.cmd.cd(fixture)

-- ── Scenarios ───────────────────────────────────────────────────────────────

if scenario == "standalone" then
  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if failed then
    finish()
    return
  end

  local signs = require("app.review.ui.signs")
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  check(
    "first file is deleted gone.lua",
    (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]) == "local gone = true"
  )

  feed("]f")
  check("]f renders main.lua, header deletion shifts line 1", wait_line1("fn_1"))
  check("filetype set", vim.bo[buf].filetype == "lua", vim.bo[buf].filetype)

  local marks = vim.api.nvim_buf_get_extmarks(buf, signs.ns, 0, -1, { details = true })
  local counts = { bg = 0, word = 0, virt = 0, virt_row0 = 0, hl_eol = 0, sign = 0 }
  for _, m in ipairs(marks) do
    local d = m[4]
    if d.priority == 100 and d.hl_group then counts.bg = counts.bg + 1 end
    if d.priority == 1000 then counts.word = counts.word + 1 end
    if d.virt_lines then
      counts.virt = counts.virt + 1
      if m[2] == 0 and d.virt_lines_above then counts.virt_row0 = counts.virt_row0 + 1 end
    end
    if d.hl_eol then counts.hl_eol = counts.hl_eol + 1 end
    if d.sign_text then counts.sign = counts.sign + 1 end
  end
  check("bg extmarks at priority 100", counts.bg > 0, counts.bg)
  check("word-diff extmarks at priority 1000", counts.word > 0, counts.word)
  check("del virt_lines present", counts.virt > 0, counts.virt)
  check("row-0 deletion virt_lines_above present", counts.virt_row0 > 0, counts.virt_row0)
  check("hl_eol fill marks present", counts.hl_eol > 0, counts.hl_eol)
  check("sign marks present", counts.sign > 0, counts.sign)

  local closed = false
  for l = 1, vim.api.nvim_buf_line_count(buf) do
    if vim.api.nvim_win_call(win, function() return vim.fn.foldclosed(l) end) ~= -1 then
      closed = true
      break
    end
  end
  check("context folded", closed)
  check("foldmethod manual", vim.wo[win].foldmethod == "manual", vim.wo[win].foldmethod)

  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  feed("]h")
  local fwd = vim.api.nvim_win_get_cursor(win)[1]
  check("]h advances cursor", fwd > 1, "1 -> " .. fwd)
  feed("[h")
  check("[h goes back", vim.api.nvim_win_get_cursor(win)[1] < fwd)

  feed("]f")
  check("]f renders untracked.lua", wait_line1("fresh"))
  local add_marks = 0
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, signs.ns, 0, -1, { details = true })) do
    if m[4].hl_group == "ReviewDiffAdd" then add_marks = add_marks + 1 end
  end
  check("untracked lines marked added", add_marks > 0, add_marks)

  -- Save watcher: external edit + FocusGained refreshes the render.
  vim.fn.writefile({ "local fresh = 1", "print(fresh)", 'print("watcher saw me")' }, fixture .. "/untracked.lua")
  vim.cmd("doautocmd FocusGained")
  local refreshed = vim.wait(8000, function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return lines[3] ~= nil and lines[3]:match("watcher saw me") ~= nil
  end, 100)
  check("watcher refresh on FocusGained", refreshed)

  finish()
elseif scenario == "degraded" then
  -- codediff's require must be attempted exactly once and rendering must
  -- degrade to no word highlights (no crash, no repeated installer runs).
  _G.__cd_attempts = 0
  package.loaded["codediff.core.diff"] = nil
  package.preload["codediff.core.diff"] = function()
    _G.__cd_attempts = _G.__cd_attempts + 1
    error("simulated missing libvscode-diff")
  end

  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  feed("]f")
  check("main.lua rendered", wait_line1("fn_1"))

  local signs = require("app.review.ui.signs")
  local counts = { bg = 0, word = 0, virt = 0 }
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, signs.ns, 0, -1, { details = true })) do
    if m[4].priority == 100 and m[4].hl_group then counts.bg = counts.bg + 1 end
    if m[4].priority == 1000 then counts.word = counts.word + 1 end
    if m[4].virt_lines then counts.virt = counts.virt + 1 end
  end
  check("diff still renders (bg marks)", counts.bg > 0, counts.bg)
  check("del virt_lines still render", counts.virt > 0, counts.virt)
  check("no word-diff marks", counts.word == 0, counts.word)
  check("require attempted exactly once", _G.__cd_attempts == 1, _G.__cd_attempts)

  finish()
elseif scenario == "embedded" then
  -- Boot as the default app; :Review must open a tab, render, load review's
  -- own plugins/ dir (the launch→load framework path), and q must restore.
  local tabs_before = #vim.api.nvim_list_tabpages()
  local ok = pcall(vim.cmd, "Review")
  check(":Review runs", ok)
  check("render completed", wait_line1())
  check("opens a new tab", #vim.api.nvim_list_tabpages() == tabs_before + 1)
  check(
    "review plugins/ loaded via launch",
    package.loaded["app.review.plugins.diff"] ~= nil
  )
  check(
    "renders first file",
    (vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]) == "local gone = true"
  )
  feed("q")
  vim.wait(2000, function()
    return #vim.api.nvim_list_tabpages() == tabs_before
  end, 50)
  check("q closes back to host tab", #vim.api.nvim_list_tabpages() == tabs_before)

  finish()
elseif scenario == "stack" then
  -- $REVIEW_KIND=stack is set by the runner; exercises run()'s env resolution.
  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if failed then
    finish()
    return
  end
  local win = vim.api.nvim_get_current_win()
  local function winbar()
    return vim.wo[win].winbar or ""
  end

  -- Changeset order: uncommitted first, then commits base→head.
  check(
    "uncommitted changeset first (dirty base.lua rendered)",
    (vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]) == "local base = 2 -- dirty",
    vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
  )
  check("winbar shows changeset 1/3", winbar():find("[1/3", 1, true) ~= nil, winbar())

  feed("]c")
  check("]c jumps to first commit changeset (a1.lua)", wait_line1("a1"))
  check("winbar shows changeset 2/3 with subject", winbar():find("[2/3 add a1]", 1, true) ~= nil, winbar())

  feed("]f")
  check("]f crosses changeset boundary (b1.lua)", wait_line1("b1"))
  check("winbar shows changeset 3/3", winbar():find("[3/3 add b1]", 1, true) ~= nil, winbar())

  feed("[c")
  check("[c jumps back to previous changeset", wait_line1("a1"))

  finish()
else
  check("known scenario", false, scenario)
  finish()
end
