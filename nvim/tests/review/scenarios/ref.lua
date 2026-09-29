-- main..feature over the stack fixture (base commit on main, feature branch
-- with two commits, plus a dirty uncommitted file). Exercises the range
-- path: one changeset spanning both endpoint trees, read-only, worktree
-- excluded (the dirty base.lua edit must never surface).
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

  check("opens on the first file (a1.lua)", wait_line1("a1"))
  -- One changeset for the whole span: set_winbar (docket.lua:150) omits the
  -- "[i/n title]" bracket entirely — only the title and file position show.
  check(
    "winbar shows the range title and file position, no changeset bracket",
    winbar():find("main..feature", 1, true) ~= nil and winbar():find("a1.lua (1/2)", 1, true) ~= nil,
    winbar()
  )

  local dk = require("app.review")._active_docket()
  check("exactly one changeset spanning both endpoints", #dk.changesets == 1, #dk.changesets)
  check("source is read-only (can_stage() == false)", dk.source:can_stage() == false)
  check("no split row2 window", dk._win2 == nil)

  -- Outline: only the two committed files, never the dirty worktree one.
  local picker = wait_outline(2)
  check("outline picker open", picker ~= nil)
  if picker then
    local paths = {}
    for _, it in ipairs(picker:items()) do
      if it.type == "file" and it.change then
        table.insert(paths, it.change.path)
      end
    end
    table.sort(paths)
    check("outline lists only the 2 committed files", vim.deep_equal(paths, { "a1.lua", "b1.lua" }), paths)
  end

  focus_diff()
  feed("]f")
  check("]f advances to the second file (b1.lua)", wait_line1("b1"))
  check("winbar shows file position 2/2", winbar():find("b1.lua (2/2)", 1, true) ~= nil, winbar())

  -- Staging keymaps must no-op: git diff --cached stays empty.
  feed("<leader>rs")
  vim.wait(300, function()
    return false
  end, 50)
  local cwd = vim.fn.getcwd()
  local staged = vim.system({ "git", "diff", "--cached" }, { cwd = cwd, text = true }):wait().stdout
  check("<leader>rs no-ops: git diff --cached stays empty", staged == "")

  -- Unit cycle: combined (header + 2 files) → commit (2 headers + 2 files),
  -- one changeset per commit on the range, newest current.
  if picker then
    picker:focus("list")
    feed("i")
    vim.wait(4000, function()
      return picker:count() == 4
    end, 50)
    check("commit unit has 4 items (2 headers + 2 files)", picker:count() == 4, picker:count())
    local headers = {}
    for _, it in ipairs(picker:items()) do
      if it.type == "changeset" then
        table.insert(headers, it.changeset)
      end
    end
    check("commit unit has a header per commit", #headers == 2, #headers)
    if #headers == 2 then
      -- Headers display head-first, so the newest commit is first.
      check("newest commit is marked current", headers[1].current == true and not headers[2].current, vim.inspect(headers[1]))
    end
    feed("i")
    vim.wait(4000, function()
      return picker:count() == 3
    end, 50)
    check("cycling again returns to combined (3 items)", picker:count() == 3, picker:count())
  end

  finish()
end
