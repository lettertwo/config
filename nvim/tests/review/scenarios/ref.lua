-- REVIEW_KIND=ref REVIEW_REF=main..feature over the stack fixture (base commit
-- on main, feature branch with two commits, plus a dirty uncommitted file).
-- Exercises the range path: one changeset per commit, read-only degradation,
-- and worktree exclusion (the dirty base.lua edit must never surface).
return function(H)
  local check, finish, feed = H.check, H.finish, H.feed
  local focus_diff, diff_win, diff_line1, wait_line1, wait_outline =
    H.focus_diff, H.diff_win, H.diff_line1, H.wait_line1, H.wait_outline

  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if H.failed() then
    finish()
    return
  end
  local win = (diff_win())
  local function winbar()
    return vim.wo[win].winbar or ""
  end

  check("opens on the first commit's file (a1.lua)", wait_line1("a1"))
  check("winbar shows changeset 1/2 with subject", winbar():find("[1/2 add a1]", 1, true) ~= nil, winbar())

  local dk = require("app.review")._active_docket()
  check("source is read-only (can_stage() == false)", dk.source:can_stage() == false)
  check("no split row2 window", dk._win2 == nil)

  -- Flat outline: only the two committed files, never the dirty worktree one.
  local picker = wait_outline(2)
  check("outline picker open (flat mode)", picker ~= nil)
  if picker then
    local paths = {}
    for _, it in ipairs(picker:items()) do
      if it.type == "file" and it.change then
        table.insert(paths, it.change.path)
      end
    end
    table.sort(paths)
    check("flat outline lists only the 2 committed files", vim.deep_equal(paths, { "a1.lua", "b1.lua" }), paths)
  end

  focus_diff()
  feed("]c")
  check("]c advances to the second changeset (b1.lua)", wait_line1("b1"))
  check("winbar shows changeset 2/2 with subject", winbar():find("[2/2 add b1]", 1, true) ~= nil, winbar())

  -- Staging keymaps must no-op: git diff --cached stays empty.
  feed("<leader>rs")
  vim.wait(300, function()
    return false
  end, 50)
  local cwd = vim.fn.getcwd()
  local staged = vim.system({ "git", "diff", "--cached" }, { cwd = cwd, text = true }):wait().stdout
  check("<leader>rs no-ops: git diff --cached stays empty", staged == "")

  finish()
end
