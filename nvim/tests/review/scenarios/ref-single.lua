-- A commit-ish over the stack fixture: single-changeset review diffing
-- <sha>^..<sha>, flat outline mode. Uses a raw sha rather than a branch name
-- to exercise the commit-ish path — a branch name now opens that branch's
-- whole stack instead of a single commit.
return function(H)
  local check, finish = H.check, H.finish
  local diff_win, wait_line1, wait_outline = H.diff_win, H.wait_line1, H.wait_outline

  local cwd = vim.fn.getcwd()
  local sha = vim.trim(vim.system({ "git", "rev-parse", "HEAD" }, { cwd = cwd, text = true }):wait().stdout)

  _G.App.launch("review", { context = "standalone", args = { source = sha } })
  check("render completed", wait_line1())
  if H.failed() then
    finish()
    return
  end
  local win = (diff_win())
  local function winbar()
    return vim.wo[win].winbar or ""
  end

  check("opens on the single commit's file (b1.lua)", wait_line1("b1"))
  -- With exactly one changeset, set_winbar (docket.lua:150) omits the
  -- "[i/n title]" bracket entirely — only the title and file position show.
  -- The title is the source argument itself (the sha), not the resolved
  -- commit's subject.
  check(
    "winbar shows the sha and file position, no changeset bracket",
    winbar():find(sha, 1, true) ~= nil and winbar():find("b1.lua (1/1)", 1, true) ~= nil,
    winbar()
  )

  local dk = require("app.review")._active_docket()
  check("exactly one changeset", #dk.changesets == 1, #dk.changesets)
  check("default outline mode is flat", dk.source.default_outline_mode == "flat")
  check("source is read-only (can_stage() == false)", dk.source:can_stage() == false)

  local picker = wait_outline(1)
  check("outline picker open (flat mode)", picker ~= nil)
  if picker then
    check("outline has exactly 1 file item", picker:count() == 1, picker:count())
  end

  finish()
end
