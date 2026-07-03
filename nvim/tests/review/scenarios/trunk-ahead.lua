return function(H)
  local check, finish = H.check, H.finish
  local focus_diff, diff_win, diff_line1, wait_line1 = H.focus_diff, H.diff_win, H.diff_line1, H.wait_line1

  -- On trunk, ahead of upstream: the in-flight commits are the stack.
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
  focus_diff()

  check("opens on the uncommitted changeset (dirty base.lua)", diff_line1() == "local base = 2 -- dirty")
  check("three changesets, uncommitted at the head", winbar():find("[3/3 Uncommitted Changes]", 1, true) ~= nil, winbar())

  H.feed("[c")
  check("[c walks down to newest unpushed commit", wait_line1("b1"))
  check("newest subject in winbar", winbar():find("[2/3 unpushed two]", 1, true) ~= nil, winbar())

  H.feed("[c")
  check("[c walks down to oldest unpushed commit", wait_line1("a1"))
  check("oldest subject in winbar", winbar():find("[1/3 unpushed one]", 1, true) ~= nil, winbar())

  finish()
end
