return function(H, fixture)
  local check, finish, feed, wait_outline = H.check, H.finish, H.feed, H.wait_outline

  -- gh-stack tracks two branches (a1 on main, b1 on a1), two commits each —
  -- exercises the commits toggle's branch-graph path (the git-log fallback
  -- used by tests/review/scenarios/stack.lua is already one node per commit,
  -- so toggling there would be a no-op).
  _G.App.launch("review", { context = "standalone" })

  -- Branch mode, head-first display (stack.lua's default_stack_order): 2
  -- headers (b1, a1) + 4 files (each branch's own two-commit diff). Focus is
  -- b1 (checked out), whose diff lists b1a.lua before b1b.lua, so the docket
  -- opens on b1a.lua — the toggle below pins to that path, not the branch's
  -- newest commit.
  local picker = wait_outline(6)
  check("outline picker open (branch mode)", picker ~= nil)
  check("branch mode has 6 items (2 headers + 4 files)", picker and picker:count() == 6, picker and picker:count())
  if not picker then
    finish()
    return
  end

  local function header_titles()
    local titles = {}
    for _, it in ipairs(picker:items()) do
      if it.type == "changeset" then
        table.insert(titles, it.changeset.title)
      end
    end
    return titles
  end
  check(
    "branch headers show branch names, head-first",
    vim.deep_equal(header_titles(), { "b1", "a1" }),
    table.concat(header_titles(), ",")
  )

  H.focus_diff()
  check("opens on b1's first file (b1a.lua)", H.wait_line1("b1a"))

  -- ── Toggle commits on ────────────────────────────────────────────────────
  picker:focus("list")
  feed("c")
  vim.wait(4000, function()
    return picker:count() == 8
  end, 50)
  check("commits mode has 8 items (4 commit headers + 4 files)", picker:count() == 8, picker:count())

  local function commit_headers()
    local headers = {}
    for _, it in ipairs(picker:items()) do
      if it.type == "changeset" then
        table.insert(headers, it.changeset)
      end
    end
    return headers
  end
  local headers = commit_headers()
  check("commits mode has 4 commit headers", #headers == 4, #headers)
  if #headers == 4 then
    check(
      "commit headers carry a branch label, head-first",
      headers[1].branch == "b1" and headers[4].branch == "a1",
      vim.inspect(vim.tbl_map(function(h) return h.branch end, headers))
    )
    check(
      "commit headers keep subject as title, newest branch/commit first",
      headers[1].title == "b1: add b1b"
        and headers[2].title == "b1: add b1a"
        and headers[3].title == "a1: add a1b"
        and headers[4].title == "a1: add a1a",
      table.concat(vim.tbl_map(function(h) return h.title end, headers), " | ")
    )
    check("b1's newest commit is marked current", headers[1].current == true, vim.inspect(headers[1]))
  end

  -- Turning commits on pinned to the path the docket was showing (b1a.lua),
  -- landing on the one commit that touched it, not on `current`.
  check("commits-on lands on the commit that added b1a.lua", H.wait_line1("b1a"))

  -- ── [c steps commit by commit, oldest-ward, across the branch boundary ──
  feed("[c")
  check("[c crosses into a1's newest commit (a1b.lua)", H.wait_line1("a1b"))
  feed("[c")
  check("[c steps to a1's oldest commit (a1a.lua)", H.wait_line1("a1a"))

  -- ── Toggle commits off restores branch headers ───────────────────────────
  picker:focus("list")
  feed("c")
  vim.wait(4000, function()
    return picker:count() == 6
  end, 50)
  check("toggling off restores branch mode (6 items)", picker:count() == 6, picker:count())
  check(
    "branch headers are back, head-first",
    vim.deep_equal(header_titles(), { "b1", "a1" }),
    table.concat(header_titles(), ",")
  )
  -- The pre-toggle file was a1a.lua (this direction's flip fallback lands on
  -- the branch containing it, same path).
  check("commits-off lands back on a1 (a1a.lua)", H.wait_line1("a1a"))

  finish()
end
