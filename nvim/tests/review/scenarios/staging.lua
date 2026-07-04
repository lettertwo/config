return function(H, fixture)
  local check, finish, wait_line1 = H.check, H.finish, H.wait_line1

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
    return dk._rendered[2] ~= nil and dk.dv2._rendered_file == dk._rendered[2].file
  end, 50))

  -- gone.lua is a fully staged deletion → split collapses to the staged pane.
  -- The collapse is deferred: row 2 lingers open (blanked) rather than
  -- closing immediately, so a quick bounce back to a partial file doesn't
  -- thrash the window.
  local win2_before = dk._win2
  focus_path("gone.lua")
  check("fully staged file collapses split to staged pane", wait_view(1, "staged"), rendered_roles())
  check(
    "second row window lingers open during the debounce",
    dk._win2 == win2_before and vim.api.nvim_win_is_valid(dk._win2)
  )
  check("lingering row 2 is blanked, not showing stale staged content", dk.dv2._rendered_file == nil)

  -- Bounce back to a partial file before the debounce elapses: row 2 must
  -- be the same window throughout, never torn down and recreated.
  focus_path("main.lua")
  check("split renders two rows again after bouncing back", wait_view(2, "unstaged"), rendered_roles())
  check(
    "second row window was never torn down across the bounce",
    dk._win2 == win2_before and vim.api.nvim_win_is_valid(dk._win2)
  )

  -- Settle on gone.lua this time and let the debounce actually fire.
  focus_path("gone.lua")
  check("fully staged file collapses split to staged pane", wait_view(1, "staged"), rendered_roles())
  check(
    "second row window eventually closes once settled",
    vim.wait(2000, function()
      return not (dk._win2 and vim.api.nvim_win_is_valid(dk._win2))
    end, 50)
  )

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

  -- Unstage that hunk from the staged pane (same pane-aware toggle).
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
    dk:stage_current()
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
  local review_staging = require("app.review.staging")
  local uf2 = focus_path("untracked.lua")
  if uf2 then
    dk:toggle_stage_file(uf2)
    check("toggle stages the untracked file", vim.wait(8000, function()
      return git_out("ls-files", "--cached"):match("untracked%.lua") ~= nil
    end, 100))
  end
  -- Drain the queue before the toggle_all round trip: toggle_all resolves
  -- stage-vs-unstage from live git status when its op runs (like
  -- toggle_file), so if it queues behind a not-yet-run op, it reads state
  -- that predates that op's effect and picks the wrong direction.
  check("staging queue drained before toggle_all", vim.wait(8000, function()
    return review_staging._queue_len() == 0
  end, 100))

  -- toggle_all: by this point the fixture is fully staged (gone.lua's
  -- re-staged deletion, main.lua's staged edits, and the just-toggled
  -- untracked.lua all have nothing left unstaged), so the first call
  -- unstages everything and the second restages it. Each check also waits
  -- for the queue to drain, not just for git's end state, so the next
  -- toggle_all can't queue behind a not-yet-run op and read stale status.
  dk:toggle_all()
  check("toggle_all (unstage direction) empties the index diff", vim.wait(8000, function()
    return git_out("diff", "--cached") == "" and review_staging._queue_len() == 0
  end, 100))
  dk:toggle_all()
  check("toggle_all (stage direction) empties the worktree diff", vim.wait(8000, function()
    return git_out("diff") == ""
      and git_out("ls-files", "--others", "--exclude-standard") == ""
      and review_staging._queue_len() == 0
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
  -- refresh() is async: wait for its rebuilt FileChange objects (main.lua's
  -- new tail_marker hunk) before focus_path re-resolves the file, otherwise
  -- focus_path can grab a FileChange that refresh is about to replace, and
  -- the diff pane's render never syncs to the object that ends up current.
  check("refresh picks up the worktree edit", vim.wait(8000, function()
    for _, f in ipairs(dk.files) do
      if f.path == "main.lua" and f.hunks and #f.hunks >= 2 then
        return true
      end
    end
    return false
  end, 100))
  focus_path("main.lua")
  -- A watcher-triggered refresh queued behind an earlier index touch (e.g.
  -- from the toggle_all round trip above) can still be in flight here; its
  -- stale `current_path` snapshot (taken before this focus_path call) can
  -- re-focus an older file and clobber the render right after it lands. Poll
  -- with focus_path repeated on every tick so it reclaims focus once that
  -- straggler settles.
  check("expand precondition: single unstaged row", vim.wait(8000, function()
    focus_path("main.lua")
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
end
