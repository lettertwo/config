return function(H, fixture)
  local check, finish, feed, wait_line1, wait_outline = H.check, H.finish, H.feed, H.wait_line1, H.wait_outline

  -- Non-file outline rows (dir, changeset): peek (K), subtree stage toggle
  -- (<Space>), and jump-to-first-file (<CR>). Fixture: a mid-stack changeset
  -- (a1 = "add b") whose src/ tree is {a.lua, b.lua} only — the worktree
  -- also has c.lua (added by a later commit) and d.lua (untracked), so a
  -- dir-peek that accidentally read the worktree instead of a1's head_ref
  -- would show all four and this scenario would catch it.
  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if H.failed() then
    finish()
    return
  end
  local dk = require("app.review")._active_docket()

  local function git_out(...)
    local r = vim.system({ "git", "--no-optional-locks", ... }, { cwd = fixture, text = true }):wait()
    return r.stdout or ""
  end

  -- Stack source defaults to stack mode, head-first display order: item 1 =
  -- Uncommitted header, then "add c" (b1), then "add b" (a1).
  local picker = wait_outline(7)
  check("outline picker open (stack mode)", picker ~= nil)
  check("outline has 7 items (3 headers + 4 files)", picker and picker:count() == 7, picker and picker:count())
  if not picker then
    finish()
    return
  end

  -- Move the list cursor to the Nth item (1-based) from the top. Uses the
  -- list's own view() API (the same one outline.lua's sync_to_current calls)
  -- rather than simulated j/k motions, which don't reliably address rows in
  -- a tree-rendered list.
  local function goto_item(n)
    picker:focus("list")
    picker.list:view(n)
  end

  local function find_item(pred)
    for i, it in ipairs(picker:items()) do
      if pred(it) then
        return it, i
      end
    end
  end

  -- ── <CR> on a changeset header jumps to its first file ──────────────────
  local a1_header, a1_idx = find_item(function(it)
    return it.type == "changeset" and it.changeset.title == "add b"
  end)
  check("found a1's header (add b)", a1_header ~= nil)
  if a1_header then
    goto_item(a1_idx)
    feed("<CR>")
    check(
      "<CR> on a1's header lands on its first (only) file, src/b.lua",
      wait_line1("local b = 1"),
      dk:current_file() and dk:current_file().path
    )
  end

  -- ── Switch to stack-tree so dir rows exist ───────────────────────────────
  picker:focus("list")
  feed("i") -- stack -> stack-tree
  vim.wait(4000, function()
    return picker:count() > 7
  end, 50)
  check("stack-tree mode nests src/ dirs under each header", picker:count() > 7, picker:count())
  -- The picker's item order settles asynchronously after a mode switch
  -- (matcher/topk reprocessing) — `count()` can already read the new total
  -- while `items()`'s index-to-item mapping is still shifting underneath
  -- it. Let it settle before trusting any index derived from items().
  vim.wait(500, function()
    return false
  end, 100)

  local function find_dir_under(changeset_title)
    return find_item(function(it)
      return it.type == "dir" and it.path == "src" and it.parent and it.parent.type == "changeset" and it.parent.changeset.title == changeset_title
    end)
  end

  -- The peek float, if open. open_floating_preview tags its window with a
  -- `w:<focus_id>` var (used internally to relocate/refocus it on a repeat
  -- press) — a generic "any floating window" scan would also catch the
  -- outline picker's own list/input windows, which snacks renders as
  -- floats too.
  local function find_float()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.w[w].review_peek ~= nil then
        return w
      end
    end
  end

  local function wait_float()
    local win
    vim.wait(4000, function()
      win = find_float()
      return win ~= nil
    end, 50)
    return win
  end

  local function close_float()
    local w = find_float()
    if w and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end

  -- ── K on the mid-stack dir peeks the CHANGESET'S TREE, not the worktree ──
  local a1_dir, a1_dir_idx = find_dir_under("add b")
  check("found a1's src/ dir row", a1_dir ~= nil)
  if a1_dir then
    goto_item(a1_dir_idx)
    feed("K")
    local win = wait_float()
    check("K opens a peek float for the mid-stack dir", win ~= nil)
    if win then
      local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
      check("a1's src/ peek lists a.lua (unchanged ancestor)", text:match("a%.lua") ~= nil, text)
      check("a1's src/ peek lists b.lua (this changeset's add)", text:match("b%.lua") ~= nil, text)
      check("a1's src/ peek does NOT list c.lua (added by a later commit)", text:match("c%.lua") == nil, text)
      check("a1's src/ peek does NOT list d.lua (untracked in the worktree only)", text:match("d%.lua") == nil, text)

      -- The float is repositioned past the ~35-col outline sidebar so it
      -- overlaps the diff panes, and sized to its own content rather than
      -- squeezed to sidebar width (open_floating_preview's default clamps
      -- to whatever window was current at open time) — checked by content
      -- fitting unwrapped, since this particular peek's lines are short
      -- enough that a fixed-width assertion wouldn't distinguish "sized to
      -- content" from "still sidebar-clamped".
      local cfg = vim.api.nvim_win_get_config(win)
      check("peek float is anchored past the sidebar, over the diff panes", cfg.col >= 35, cfg.col)
      local longest = 0
      for _, l in ipairs(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)) do
        longest = math.max(longest, vim.fn.strdisplaywidth(l))
      end
      check("peek float width fits its longest line unwrapped", cfg.width >= longest, { width = cfg.width, longest = longest })
    end
    close_float()
  end

  -- ── K again (same row) refocuses the same float instead of stacking a
  -- second one ── open_floating_preview creates the float unfocused
  -- (nvim_open_win(..., enter=false)); a REPEAT press while its focus_id's
  -- source buffer is still current is what jumps focus into it.
  if a1_dir then
    goto_item(a1_dir_idx)
    feed("K")
    local win1 = wait_float()
    check("first K leaves focus on the outline list", win1 ~= nil and vim.api.nvim_get_current_win() ~= win1)
    feed("K")
    vim.wait(500, function()
      return false
    end, 50) -- let the (already-open) float settle
    local win2 = find_float()
    check("K on an already-open peek refocuses it (same window)", win1 ~= nil and win1 == win2, { win1, win2 })
    check("a repeat K jumps focus into the peek float", vim.api.nvim_get_current_win() == win2)
    close_float()
    picker:focus("list")
  end

  -- ── q while the FLOAT ITSELF is focused closes the window, not just its
  -- buffer ── open_floating_preview's own `q` is `:bdelete`, which empties
  -- the buffer but leaves the (now-blank) floating window open, since a
  -- window always has to show some buffer. Our override must actually close
  -- the window.
  if a1_dir then
    goto_item(a1_dir_idx)
    feed("K")
    wait_float()
    feed("K") -- repeat press: focuses the float itself (async — the reuse
    -- path re-fetches dir content before reopening/focusing)
    vim.wait(2000, function()
      local w = find_float()
      return w ~= nil and vim.api.nvim_get_current_win() == w
    end, 50)
    local floatwin = find_float()
    check("second K focused the float", floatwin ~= nil and vim.api.nvim_get_current_win() == floatwin)
    if floatwin then
      feed("q")
      check(
        "q from inside the float closes the WINDOW (not just emptying its buffer)",
        vim.wait(2000, function()
          return not vim.api.nvim_win_is_valid(floatwin)
        end, 50)
      )
      check("no peek float lingers after closing from inside", find_float() == nil)
    end
    picker:focus("list")
  end

  -- ── q dismisses an open peek float instead of closing the review ────────
  if a1_dir then
    goto_item(a1_dir_idx)
    feed("K")
    check("peek float open before q", wait_float() ~= nil)
    feed("q")
    check("q closes the peek float", vim.wait(2000, function()
      return find_float() == nil
    end, 50))
    check("q with a float open does NOT close the review", require("app.review")._active_docket() ~= nil)
    check("outline picker is still open after dismissing the float", picker:count() > 0)
    picker:focus("list")
  end

  -- ── K on the uncommitted dir falls back to fs_scandir (no head_ref) ─────
  local un_dir, un_dir_idx = find_dir_under("Uncommitted Changes")
  check("found the uncommitted src/ dir row", un_dir ~= nil)
  if un_dir then
    goto_item(un_dir_idx)
    feed("K")
    local win = wait_float()
    check("K opens a peek float for the uncommitted dir", win ~= nil)
    if win then
      local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
      check("uncommitted src/ peek lists all four worktree entries", text:match("a%.lua") and text:match("b%.lua") and text:match("c%.lua") and text:match("d%.lua") ~= nil, text)
    end
    close_float()
    picker:focus("list")
  end

  -- ── K on a single-commit changeset header shows the commit message + stat ─
  local b1_header, b1_idx = find_item(function(it)
    return it.type == "changeset" and it.changeset.title == "add c"
  end)
  check("found b1's header (add c)", b1_header ~= nil)
  if b1_header then
    goto_item(b1_idx)
    feed("K")
    local win = wait_float()
    check("K opens a peek float for a changeset header", win ~= nil)
    if win then
      local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
      check("changeset peek shows the commit subject", text:match("add c") ~= nil, text)
      check("changeset peek shows the diffstat", text:match("c%.lua") ~= nil, text)
    end
    close_float()
    picker:focus("list")
  end

  -- ── <Space> on a dir toggles the whole subtree, live-state aware ────────
  if un_dir then
    goto_item(un_dir_idx)
    feed("<Space>")
    check(
      "<Space> on the uncommitted src/ dir stages the dirty edit and the untracked file",
      vim.wait(8000, function()
        return git_out("diff", "--cached", "--", "src"):match("dirty") ~= nil
          and git_out("ls-files", "--cached", "--", "src/d.lua"):match("d%.lua") ~= nil
      end, 100),
      git_out("status", "--porcelain", "--", "src")
    )

    goto_item(un_dir_idx)
    feed("<Space>")
    check(
      "<Space> again unstages the subtree (live-state toggle)",
      vim.wait(8000, function()
        return git_out("diff", "--cached", "--", "src") == "" and git_out("ls-files", "--cached", "--", "src/d.lua") == ""
      end, 100),
      git_out("status", "--porcelain", "--", "src")
    )
  end

  finish()
end
