return function(H, fixture)
  local check, finish, feed = H.check, H.finish, H.feed
  local focus_diff, diff_win, wait_line1, wait_outline = H.focus_diff, H.diff_win, H.wait_line1, H.wait_outline

  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if H.failed() then
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
end
