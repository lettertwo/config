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

-- Trunk-ahead fixture: on main with an upstream, two unpushed commits, and a
-- dirty worktree. "review stack" here should show what's in flight, not just
-- the last commit.
local function build_trunk_ahead_fixture()
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

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

-- The outline picker takes focus when the review opens, so scenarios locate
-- and drive the diff window explicitly rather than assuming it is current.
local function diff_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.api.nvim_buf_get_name(b):match("review://") then
      return w, b
    end
  end
end

local function focus_diff()
  local w, b = diff_win()
  if w then
    vim.api.nvim_set_current_win(w)
  end
  return w, b
end

local function diff_line1()
  local _, b = diff_win()
  if not b then
    return ""
  end
  return vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] or ""
end

local function wait_line1(pat)
  return vim.wait(8000, function()
    local l = diff_line1()
    return l ~= "" and not l:match("^Loading") and (not pat or l:match(pat) ~= nil)
  end, 50)
end

-- The review outline picker, once its finder has produced items.
local function wait_outline(min_items)
  local picker
  vim.wait(8000, function()
    local pickers = _G.Snacks and Snacks.picker and Snacks.picker.get() or {}
    picker = pickers[1]
    return picker ~= nil and picker:count() >= (min_items or 1)
  end, 50)
  return picker
end

local fixture = scenario == "stack" and build_stack_fixture()
  or scenario == "trunk-ahead" and build_trunk_ahead_fixture()
  or build_fixture()
vim.cmd.cd(fixture)

-- ── Scenarios ───────────────────────────────────────────────────────────────

if scenario == "standalone" then
  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if failed then
    finish()
    return
  end

  -- M5 opens on the staging split by default; this scenario asserts the
  -- combined view (the staging scenario covers the split). Content is the
  -- same either way for gone.lua, so no re-render race here.
  local dk0 = require("app.review")._active_docket()
  dk0.state.zoom = "combined"
  dk0:show_file()

  -- Outline: flat mode, one item per file (proves the standalone snacks
  -- bootstrap — this scenario runs without the default app's snacks).
  local picker = wait_outline(3)
  check("outline picker open", picker ~= nil)
  check("outline lists 3 files (flat)", picker and picker:count() == 3, picker and picker:count())

  local signs = require("app.review.ui.signs")
  local win, buf = focus_diff()
  check("diff window present", win ~= nil)

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

  -- ── Side-by-side (M4) ─────────────────────────────────────────────────────
  -- The refresh above re-rendered the outline, whose focus-follow may have
  -- moved the docket back to item 1; target main.lua deterministically.
  local dk = require("app.review")._active_docket()
  for _, f in ipairs(dk.files) do
    if f.path == "main.lua" then
      dk:focus_file(f)
      break
    end
  end
  check("back on main.lua for sbs checks", wait_line1("fn_1"))

  -- Locate the two panes by buffer name (the //old suffix marks the left).
  local function sbs_wins()
    local right_w, left_w
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
      if name:match("review://.*//old$") then
        left_w = w
      elseif name:match("review://") then
        right_w = w
      end
    end
    return right_w, left_w
  end

  focus_diff()
  feed(vim.g.mapleader .. "rl")
  local rwin, lwin = sbs_wins()
  check("toggle opens a left pane", rwin ~= nil and lwin ~= nil)

  if lwin then
    local lbuf = vim.api.nvim_win_get_buf(lwin)
    local rbuf = vim.api.nvim_win_get_buf(rwin)
    local rendered = vim.wait(8000, function()
      return (vim.api.nvim_buf_get_lines(lbuf, 0, 1, false)[1] or ""):match("header comment") ~= nil
    end, 50)
    check("left pane shows the HEAD content (deleted line 1 present)", rendered)
    check("scrollbind on both panes", vim.wo[rwin].scrollbind and vim.wo[lwin].scrollbind)

    -- Extmark survey per side.
    local function survey(b)
      local c = { bg_del = 0, bg_add = 0, word = 0, filler = 0, filler_above0 = 0 }
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(b, signs.ns, 0, -1, { details = true })) do
        local d = m[4]
        if d.end_col and d.hl_group == "ReviewDiffDelete" then c.bg_del = c.bg_del + 1 end
        if d.end_col and d.hl_group == "ReviewDiffAdd" then c.bg_add = c.bg_add + 1 end
        if d.priority == 1000 then c.word = c.word + 1 end
        if d.virt_lines and d.virt_lines[1] and d.virt_lines[1][1][2] == "ReviewDiffFiller" then
          c.filler = c.filler + 1
          if m[2] == 0 and d.virt_lines_above then c.filler_above0 = c.filler_above0 + 1 end
        end
      end
      return c
    end
    local lc, rc = survey(lbuf), survey(rbuf)
    check("left pane has del marks, no add marks", lc.bg_del > 0 and lc.bg_add == 0, vim.inspect(lc))
    check("right pane has add marks, no del marks", rc.bg_add > 0 and rc.bg_del == 0, vim.inspect(rc))
    check("word-diff on both sides", lc.word > 0 and rc.word > 0)
    -- The deleted line 1 has no new-side row: filler above row 0 on the right.
    check("row-0 deletion filler above right row 0", rc.filler_above0 > 0, vim.inspect(rc))

    -- Folds: both panes fold context; open/close state mirrors.
    local function closed_count(w)
      local b = vim.api.nvim_win_get_buf(w)
      local n = 0
      for l = 1, vim.api.nvim_buf_line_count(b) do
        if vim.api.nvim_win_call(w, function() return vim.fn.foldclosed(l) end) == l then
          n = n + 1
        end
      end
      return n
    end
    check("both panes have context folds", closed_count(rwin) > 0 and closed_count(lwin) > 0)
    -- CursorMoved/WinScrolled never fire under feedkeys("x") headless (for
    -- ANY key) — these assertions pass only via the buffer-local fold-key
    -- remaps, which is exactly the deterministic path under test (in-place
    -- zR/zM fire no autocmd even interactively).
    vim.api.nvim_set_current_win(rwin)
    local closed_before = closed_count(lwin)
    feed("zR")
    check("fold open mirrors to the left pane", closed_count(lwin) == 0, closed_count(lwin))
    feed("zM")
    check("in-place fold close mirrors to the left pane", closed_count(lwin) == closed_before, closed_count(lwin))
    -- The autocmd safety net still has to work for fold changes outside the
    -- remaps: desync via API (normal! bypasses mappings), pump CursorMoved.
    feed("zR")
    vim.api.nvim_win_call(rwin, function()
      vim.cmd("normal! zM")
    end)
    check("API fold change desyncs the panes", closed_count(lwin) == 0 and closed_count(rwin) > 0)
    vim.cmd("doautocmd CursorMoved")
    check("autocmd safety net re-syncs the left pane", closed_count(lwin) == closed_before, closed_count(lwin))
    feed("zR")

    -- Scroll sync: jump to the bottom on the right, the left follows.
    feed("G")
    vim.cmd("redraw")
    local ltop = vim.api.nvim_win_call(lwin, function() return vim.fn.winsaveview().topline end)
    check("scrollbind drags the left pane", ltop > 1, ltop)

    -- Nav from the left pane refocuses the primary window.
    vim.api.nvim_set_current_win(lwin)
    feed("]h")
    check("left-pane nav refocuses the diff window", vim.api.nvim_get_current_win() == rwin)

    -- Toggle back to inline: one pane, del virt_lines again.
    vim.api.nvim_set_current_win(rwin)
    feed(vim.g.mapleader .. "rl")
    local rwin2, lwin2 = sbs_wins()
    check("toggle back closes the left pane", rwin2 ~= nil and lwin2 == nil)
    local back = vim.wait(8000, function()
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(rbuf, signs.ns, 0, -1, { details = true })) do
        local d = m[4]
        if d.virt_lines and d.virt_lines[1] and d.virt_lines[1][1][2] ~= "ReviewDiffFiller" then
          return true
        end
      end
      return false
    end, 50)
    check("inline render restored (del virt_lines back)", back)
  end

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
  local _, dbuf = focus_diff()
  feed("]f")
  check("main.lua rendered", wait_line1("fn_1"))

  local signs = require("app.review.ui.signs")
  local counts = { bg = 0, word = 0, virt = 0 }
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(dbuf, signs.ns, 0, -1, { details = true })) do
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
  check("renders first file", diff_line1() == "local gone = true")
  check("outline opens embedded", wait_outline(3) ~= nil)
  focus_diff()
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
  local win = (diff_win())
  local function winbar()
    return vim.wo[win].winbar or ""
  end

  -- Outline: stack source defaults to stack mode → 3 changeset headers +
  -- 3 files, with the current-position marker on the uncommitted header.
  local picker = wait_outline(6)
  check("outline picker open (stack mode)", picker ~= nil)
  check("outline has 6 items (3 headers + 3 files)", picker and picker:count() == 6, picker and picker:count())
  if picker then
    local current_headers = 0
    for _, it in ipairs(picker:items()) do
      if it.type == "changeset" and it.changeset.current then
        current_headers = current_headers + 1
      end
    end
    check("exactly one changeset marked current", current_headers == 1, current_headers)

    -- Focus-follow: moving the list cursor onto a file item renders it.
    -- Stack source defaults to head-first order (stack.lua's
    -- default_stack_order), so item 1 is the Uncommitted header and item 2
    -- is base.lua, its only file — not a1.lua.
    picker:focus("list")
    feed("gg")
    feed("j") -- item 2 = base.lua (the uncommitted changeset's file)
    check("outline focus-follow renders base.lua", wait_line1("dirty"))

    -- Explicit nav keymaps ([f/]f, [c/]c) bypass on_change entirely (they
    -- call docket methods directly), so the outline's own list cursor must
    -- still follow via sync_to_current even while the outline is focused —
    -- this is the bug this change fixes. picker:current() must match the
    -- docket's new current file after each keypress. Seed a known starting
    -- file directly (dk:focus_file) rather than relying on the flaky
    -- feedkeys-driven focus-follow above, since only the nav keymaps are
    -- under test here.
    local dk_nav = require("app.review")._active_docket()
    dk_nav:focus_file(dk_nav.files[1]) -- a1.lua
    wait_line1("a1")
    picker:focus("list")
    feed("]f")
    check(
      "]f from a focused outline advances the docket",
      wait_line1("b1"),
      dk_nav:current_file() and dk_nav:current_file().path
    )
    check(
      "]f from a focused outline repositions the outline cursor",
      picker:current() and picker:current().change == dk_nav:current_file()
    )
    feed("]c")
    check(
      "]c from a focused outline advances to the uncommitted changeset",
      wait_line1("dirty"),
      dk_nav:current_file() and dk_nav:current_file().path
    )
    check(
      "]c from a focused outline repositions the outline cursor",
      picker:current() and picker:current().change == dk_nav:current_file()
    )
    feed("[c")
    feed("[c")
  end

  -- Diff-window nav still works with the outline open. (Nav checks run
  -- before the mode-cycle checks: picker:refresh() defers a focus-restore
  -- that would otherwise steal focus mid-chain.)
  focus_diff()
  check("diff shows a1.lua after focus-follow", wait_line1("a1"))
  feed("]c")
  check("]c to next changeset (b1.lua)", wait_line1("b1"))
  feed("]c")
  check(
    "opens on the uncommitted changeset (dirty base.lua rendered)",
    wait_line1("dirty"),
    diff_line1()
  )
  check("uncommitted sits at the head (3/3)", winbar():find("[3/3 Uncommitted Changes]", 1, true) ~= nil, winbar())

  -- Mode cycle: stack → stack-tree → flat (3 items) → tree → stack (6).
  if picker then
    picker:focus("list")
    feed("i")
    feed("i")
    vim.wait(4000, function()
      return picker:count() == 3
    end, 50)
    check("mode cycle reaches flat (3 items)", picker:count() == 3, picker:count())
    feed("i")
    feed("i") -- back to stack
    vim.wait(4000, function()
      return picker:count() == 6
    end, 50)
    check("mode cycle returns to stack (6 items)", picker:count() == 6, picker:count())
  end

  -- Let the picker's deferred focus-restore land, then reset the position to
  -- the uncommitted changeset directly (focus-independent) for the walk-down.
  vim.wait(500, function()
    return false
  end, 100)
  local dk = require("app.review")._active_docket()
  dk:focus_file(dk.files[#dk.files])
  wait_line1("dirty")
  focus_diff()
  feed("[c")
  check("[c walks down to the newest commit (b1.lua)", wait_line1("b1"))
  check("winbar shows changeset 2/3 with subject", winbar():find("[2/3 add b1]", 1, true) ~= nil, winbar())

  feed("[c")
  check("[c walks down to the oldest commit (a1.lua)", wait_line1("a1"))
  check("winbar shows changeset 1/3", winbar():find("[1/3 add a1]", 1, true) ~= nil, winbar())

  feed("]f")
  check("]f crosses changeset boundary (b1.lua)", wait_line1("b1"))

  finish()
elseif scenario == "trunk-ahead" then
  -- On trunk, ahead of upstream: the in-flight commits are the stack.
  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if failed then
    finish()
    return
  end
  local win = (diff_win())
  local function winbar()
    return vim.wo[win].winbar or ""
  end
  focus_diff()

  check("opens on the uncommitted changeset (dirty base.lua)", diff_line1() == "local base = 2 -- dirty")
  check("three changesets, uncommitted at the head", winbar():find("[3/3 Uncommitted Changes]", 1, true) ~= nil, winbar())

  feed("[c")
  check("[c walks down to newest unpushed commit", wait_line1("b1"))
  check("newest subject in winbar", winbar():find("[2/3 unpushed two]", 1, true) ~= nil, winbar())

  feed("[c")
  check("[c walks down to oldest unpushed commit", wait_line1("a1"))
  check("oldest subject in winbar", winbar():find("[1/3 unpushed one]", 1, true) ~= nil, winbar())

  finish()
elseif scenario == "staging" then
  -- Staging split + actions (M5). Mutates its fixture repo via the app's
  -- staging queue and asserts against git plumbing.
  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  local dk = require("app.review")._active_docket()

  -- --no-optional-locks: the checks poll git while the app's staging queue
  -- writes the index; a bare `git status` takes index.lock to refresh the
  -- stat cache and races the queue's ops.
  local function git_out(...)
    local r = vim.system({ "git", "--no-optional-locks", ... }, { cwd = fixture, text = true }):wait()
    return r.stdout or ""
  end
  local function focus_path(path)
    for _, f in ipairs(dk.files) do
      if f.path == path then
        dk:focus_file(f)
        return f
      end
    end
  end
  local function rendered_roles()
    local roles = {}
    for _, r in ipairs(dk._rendered) do
      table.insert(roles, r.role)
    end
    return table.concat(roles, ",")
  end
  -- The role plan (dk._rendered) updates synchronously; buffers/hunk_rows
  -- land when the async render completes — wait for both.
  local function wait_view(n_rows, role1)
    return vim.wait(8000, function()
      return #dk._rendered == n_rows
        and dk._rendered[1].role == role1
        and dk.dv._rendered_file == dk._rendered[1].file
    end, 50)
  end

  -- main.lua has both staged and unstaged hunks → split renders two rows.
  focus_path("main.lua")
  local split_up = wait_view(2, "unstaged")
  check("split renders two rows for main.lua", split_up, rendered_roles())
  check("roles are unstaged,staged", rendered_roles() == "unstaged,staged")
  check("second row window exists", dk._win2 and vim.api.nvim_win_is_valid(dk._win2))
  check("staged pane renders the index side", vim.wait(8000, function()
    local l = vim.api.nvim_buf_get_lines(dk.dv2.right.bufnr, 0, -1, false)
    return #l > 1
  end, 50))

  -- gone.lua is a fully staged deletion → split collapses to the staged pane.
  focus_path("gone.lua")
  check("fully staged file collapses split to staged pane", wait_view(1, "staged"), rendered_roles())
  check("second row window closed on collapse", not (dk._win2 and vim.api.nvim_win_is_valid(dk._win2)))

  -- Stage the unstaged fn_9 hunk from the unstaged pane.
  focus_path("main.lua")
  wait_view(2, "unstaged")
  vim.api.nvim_set_current_win(dk.win)
  local hr = dk.dv.right.hunk_rows[1]
  check("unstaged pane has a hunk", hr ~= nil)
  if hr then
    vim.api.nvim_win_set_cursor(dk.win, { hr.first_diff + 1, 0 })
    dk:stage_current()
    check("stage hunk lands in the index", vim.wait(8000, function()
      return git_out("diff", "--cached"):match("compute_nine") ~= nil
    end, 100))
    -- main.lua is now fully staged → split collapses.
    check("collapse after staging everything", wait_view(1, "staged"), rendered_roles())
  end

  -- Unstage that hunk from the staged pane (pane-aware toggle on r-'s
  -- explicit sibling).
  vim.api.nvim_set_current_win(dk.win)
  local target
  for i, l in ipairs(vim.api.nvim_buf_get_lines(dk.dv.right.bufnr, 0, -1, false)) do
    if l:match("compute_nine") then
      target = i
      break
    end
  end
  check(
    "staged pane shows the staged line",
    target ~= nil,
    target == nil and table.concat(vim.api.nvim_buf_get_lines(dk.dv.right.bufnr, 0, 5, false), " | ") or nil
  )
  if target then
    vim.api.nvim_win_set_cursor(dk.win, { target, 0 })
    dk:unstage_current()
    check("unstage hunk leaves the index", vim.wait(8000, function()
      return git_out("diff", "--cached"):match("compute_nine") == nil
    end, 100))
    check("split returns after unstage", wait_view(2, "unstaged"), rendered_roles())
  end

  -- Pure-deletion staging (the POC's corrupt-patch case): delete a line in
  -- the worktree, stage that hunk.
  local lines = vim.fn.readfile(fixture .. "/main.lua")
  for i, l in ipairs(lines) do
    if l:match("return 5 %+ 5") then
      table.remove(lines, i)
      break
    end
  end
  vim.fn.writefile(lines, fixture .. "/main.lua")
  dk:refresh()
  check("refresh picks up the worktree deletion", vim.wait(8000, function()
    if #dk._rendered ~= 2 or dk.dv._rendered_file ~= dk._rendered[1].file then
      return false
    end
    for _, l in ipairs(vim.api.nvim_buf_get_lines(dk.dv.right.bufnr, 0, -1, false)) do
      if l:match("return 5 %+ 5") then
        return false
      end
    end
    return true
  end, 100))
  vim.api.nvim_set_current_win(dk.win)
  local pure_del
  for _, h in ipairs(dk.dv.right.hunk_rows) do
    local hunk = dk.dv:hunk_at(dk.win, h.first_diff)
    if hunk then
      local has_add = false
      for _, l in ipairs(hunk.lines) do
        if l.kind == "add" then
          has_add = true
        end
      end
      if not has_add then
        pure_del = h
        break
      end
    end
  end
  check("found the pure-del hunk", pure_del ~= nil)
  if pure_del then
    vim.api.nvim_win_set_cursor(dk.win, { pure_del.first_diff + 1, 0 })
    dk:stage_current()
    check("pure-del hunk stages cleanly (no corrupt patch)", vim.wait(8000, function()
      return git_out("diff", "--cached"):match("%-  return 5 %+ 5") ~= nil
    end, 100), git_out("diff", "--cached"))
  end

  -- Discard the remaining unstaged fn_9 hunk (confirm stubbed to Yes —
  -- vim.fn.confirm itself can't be monkeypatched). wait_view alone can match
  -- the settled PRE-staging view, so also require the refreshed data: after
  -- staging the fn_5 deletion, the unstaged sub is down to the fn_9 hunk.
  dk._confirm = function()
    return true
  end
  check("unstaged pane refreshed before discard", vim.wait(8000, function()
    return #dk._rendered == 2
      and dk._rendered[1].role == "unstaged"
      and dk.dv._rendered_file == dk._rendered[1].file
      and #dk.dv.right.hunk_rows == 1
  end, 100), rendered_roles() .. " hunks=" .. #dk.dv.right.hunk_rows)
  vim.api.nvim_set_current_win(dk.win)
  local dhr = dk.dv.right.hunk_rows[1]
  check("discard target hunk present", dhr ~= nil)
  if dhr then
    vim.api.nvim_win_set_cursor(dk.win, { dhr.first_diff + 1, 0 })
    dk:discard_current()
  end
  check("discard hunk reverts the worktree", vim.wait(8000, function()
    for _, l in ipairs(vim.fn.readfile(fixture .. "/main.lua")) do
      if l:match("compute_nine") then
        return false
      end
    end
    return true
  end, 100), git_out("diff"))

  -- 2×2 grid: sbs layout while the split zoom is active.
  focus_path("main.lua")
  vim.wait(8000, function()
    return #dk._rendered == 2 and dk.dv._rendered_file == dk._rendered[1].file
  end, 100)
  dk:toggle_layout()
  -- Rows must stay (near-)equal in height across the toggle: win_equal in
  -- this config skews sibling rows, so _arrange pins them explicitly.
  local th1 = vim.api.nvim_win_get_height(dk.win)
  local th2 = vim.api.nvim_win_get_height(dk._win2)
  check("rows equal height after sbs toggle", math.abs(th1 - th2) <= 1, th1 .. " vs " .. th2)
  local function review_win_count()
    local n = 0
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match("review://") then
        n = n + 1
      end
    end
    return n
  end
  check("sbs × split renders the 2×2 grid", vim.wait(8000, function()
    return review_win_count() == 4
  end, 100), review_win_count())
  dk:toggle_layout()
  check("toggle back collapses to two rows", vim.wait(8000, function()
    return review_win_count() == 2
  end, 100), review_win_count())

  -- Hunk-op fallbacks on whole-file statuses: an untracked file's "hunk"
  -- stages the file; a staged deletion's "hunk" unstages the file (plain
  -- hunk_to_patch headers can't express creations/deletions).
  local uf = focus_path("untracked.lua")
  check("untracked file present", uf ~= nil)
  if uf then
    vim.wait(8000, function()
      return #dk._rendered >= 1 and dk.dv._rendered_file == dk._rendered[1].file
    end, 100)
    vim.api.nvim_set_current_win(dk.win)
    local uhr = dk.dv.right.hunk_rows[1]
    if uhr then
      vim.api.nvim_win_set_cursor(dk.win, { uhr.first_diff + 1, 0 })
      dk:stage_current()
      check("hunk-staging an untracked file stages the whole file", vim.wait(8000, function()
        return git_out("ls-files", "--cached"):match("untracked%.lua") ~= nil
      end, 100), git_out("status", "--porcelain"))
      -- Undo for the next steps.
      dk:toggle_stage_file(uf)
      vim.wait(8000, function()
        return git_out("ls-files", "--cached"):match("untracked%.lua") == nil
      end, 100)
    end
  end

  local gf = focus_path("gone.lua")
  check("staged deletion present", gf ~= nil)
  if gf then
    local settled = vim.wait(8000, function()
      return #dk._rendered == 1
        and dk._rendered[1].role == "staged"
        and dk.dv._rendered_file == dk._rendered[1].file
    end, 100)
    check(
      "staged deletion view settles",
      settled,
      rendered_roles() .. " rendered_file=" .. tostring(dk.dv._rendered_file and dk.dv._rendered_file.path)
    )
    vim.api.nvim_set_current_win(dk.win)
    local ghr = dk.dv.right.hunk_rows[1]
    if ghr then
      vim.api.nvim_win_set_cursor(dk.win, { ghr.first_diff + 1, 0 })
      dk:stage_current() -- staged pane: unstages; deletion → file-level
      check("hunk-unstaging a staged deletion unstages the file", vim.wait(8000, function()
        return git_out("status", "--porcelain"):match(" D gone%.lua") ~= nil
      end, 100), git_out("status", "--porcelain"))
      -- Re-stage to restore fixture state.
      git_out("rm", "-q", "gone.lua")
    end
  end

  -- Outline-style file toggle on the untracked file. The toggle resolves
  -- its direction from the live index when the op runs, so a stale
  -- FileChange snapshot (refresh in flight) must not matter. The wait above
  -- for ls-files after the undo toggle guarantees it is unstaged here.
  local uf2 = focus_path("untracked.lua")
  if uf2 then
    dk:toggle_stage_file(uf2)
    check("toggle stages the untracked file", vim.wait(8000, function()
      return git_out("ls-files", "--cached"):match("untracked%.lua") ~= nil
    end, 100))
  end

  -- stage_all / unstage_all.
  dk:stage_all()
  check("stage_all empties the worktree diff", vim.wait(8000, function()
    return git_out("diff") == "" and git_out("ls-files", "--others", "--exclude-standard") == ""
  end, 100))
  dk:unstage_all()
  check("unstage_all empties the index diff", vim.wait(8000, function()
    return git_out("diff", "--cached") == ""
  end, 100))

  -- External staging is noticed by the index watcher (no manual refresh).
  git_out("add", "main.lua")
  check("index watcher refreshes on external git add", vim.wait(8000, function()
    for _, f in ipairs(dk.files) do
      if f.path == "main.lua" and (f.staged or f.staged_hunks) then
        return true
      end
    end
    return false
  end, 100))

  -- Row-2 creation while sbs is already active: staging a hunk expands the
  -- collapsed split back to two rows, and the new row must span both diff
  -- columns (regression: `belowright split` from the right pane hung row 2
  -- under the right column only). Runs last — the reset and external edits
  -- here would otherwise race the index watcher into later blocks.
  git_out("reset") -- nothing staged → split collapses to the unstaged row
  local ml = vim.fn.readfile(fixture .. "/main.lua")
  table.insert(ml, "local tail_marker = true")
  vim.fn.writefile(ml, fixture .. "/main.lua")
  dk:refresh()
  focus_path("main.lua")
  check("expand precondition: single unstaged row", vim.wait(8000, function()
    return #dk._rendered == 1
      and dk._rendered[1].role == "unstaged"
      and dk.dv._rendered_file == dk._rendered[1].file
      and #dk.dv.right.hunk_rows >= 2
  end, 100), rendered_roles() .. " hunks=" .. #dk.dv.right.hunk_rows)
  dk:toggle_layout()
  check("sbs on the single row", vim.wait(8000, function()
    return review_win_count() == 2
  end, 100), review_win_count())
  vim.api.nvim_set_current_win(dk.win)
  local xhr = dk.dv.right.hunk_rows[1]
  if xhr then
    vim.api.nvim_win_set_cursor(dk.win, { xhr.first_diff + 1, 0 })
    dk:stage_current()
    check("staging expands the split while sbs", wait_view(2, "unstaged"), rendered_roles())
    check("expanded grid has 4 review windows", vim.wait(8000, function()
      return review_win_count() == 4
    end, 100), review_win_count())
    local function col(w)
      return vim.api.nvim_win_get_position(w)[2]
    end
    check(
      "row-2 primary aligns with row-1 primary column",
      dk._win2 and vim.api.nvim_win_is_valid(dk._win2) and col(dk._win2) == col(dk.win),
      dk._win2 and vim.api.nvim_win_is_valid(dk._win2) and (col(dk._win2) .. " vs " .. col(dk.win)) or "no win2"
    )
    check(
      "row-2 left pane aligns with row-1 left column",
      dk.dv2.left.win and dk.dv.left.win and col(dk.dv2.left.win) == col(dk.dv.left.win),
      dk.dv2.left.win and dk.dv.left.win and (col(dk.dv2.left.win) .. " vs " .. col(dk.dv.left.win)) or "missing left pane"
    )
  end

  finish()
else
  check("known scenario", false, scenario)
  finish()
end
