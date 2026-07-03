return function(H)
  local check, finish, feed = H.check, H.finish, H.feed
  local focus_diff, diff_win, diff_line1, wait_line1, wait_outline =
    H.focus_diff, H.diff_win, H.diff_line1, H.wait_line1, H.wait_outline

  -- $REVIEW_KIND=stack is set by the runner; exercises run()'s env resolution.
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
end
