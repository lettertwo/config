-- Read-only peek previews for non-file outline rows (dir, changeset), opened
-- in a transient float. Uses vim.lsp.util.open_floating_preview — core API,
-- nothing LSP-specific — which supplies anchor-at-cursor, auto-close on
-- CursorMoved/BufLeave, max-height truncation, and press-key-again-to-focus
-- via a stable focus_id.

local git = require("app.review.diff.git")
local Y_STATUS = require("app.review.ui.outline").Y_STATUS

local M = {}

local FOCUS_ID = "review_peek"
local NS = vim.api.nvim_create_namespace("review_peek")

-- Walk an outline item's parent chain to the enclosing changeset header, if
-- any. flat/tree-mode dirs have no changeset parent (the whole docket is
-- shown as one tree there).
---@param item table
---@return table? -- the changeset outline item, if any
local function enclosing_changeset_item(item)
  local p = item.parent
  while p do
    if p.type == "changeset" then
      return p
    end
    p = p.parent
  end
  return nil
end

-- Decorate a one-level directory listing against the docket's changed-file
-- set: entries under review get their status glyph + the outline's Y-column
-- highlight; everything else dims as a `Comment` — "the tree mode's view,
-- completed with what didn't change." Pure; exposed for unit tests.
---@param entries {name: string, type: "dir"|"file", path: string}[]
---@param changed table<string, Review.FileChange>  path -> FileChange
---@return string[] lines
---@return {line: integer, col: integer, end_col: integer, hl_group: string}[] highlights
function M._dir_lines(entries, changed)
  local sorted = vim.deepcopy(entries)
  table.sort(sorted, function(a, b)
    if (a.type == "dir") ~= (b.type == "dir") then
      return a.type == "dir"
    end
    return a.name < b.name
  end)

  local lines, hl = {}, {}
  for _, e in ipairs(sorted) do
    local suffix = e.type == "dir" and "/" or ""
    local file = changed[e.path]
    local row = #lines
    if file then
      local y = Y_STATUS[file.status] or { "?", "Comment" }
      table.insert(lines, ("%s  %s%s"):format(y[1], e.name, suffix))
      table.insert(hl, { line = row, col = 0, end_col = 1, hl_group = y[2] })
    else
      table.insert(lines, ("   %s%s"):format(e.name, suffix))
      table.insert(hl, { line = row, col = 0, end_col = -1, hl_group = "Comment" })
    end
  end
  if #lines == 0 then
    table.insert(lines, "(empty)")
  end
  return lines, hl
end

-- Format a changeset's peek body. `item` is the outline changeset item
-- (carries `.changeset`, `._cs_idx`, `._cs_total` for the header, styled
-- like the outline row). `commits` is nil for no-ref (uncommitted)
-- changesets — diffstat only there. Single-commit ranges show the full
-- message (subject + body — the context the one-line outline title strips)
-- plus author/date; multi-commit ranges show a `git log --oneline`-style
-- list. Pure; exposed for unit tests.
---@param item table
---@param commits {sha: string, author: string, date: string, subject: string, body: string}[]?
---@param stat string?
---@return string[] lines
---@return {line: integer, col: integer, end_col: integer, hl_group: string}[] highlights
function M._changeset_lines(item, commits, stat)
  local cs = item.changeset
  local header = ("[%d/%d] %s"):format(item._cs_idx or 1, item._cs_total or 1, cs.title)
  if cs.pr_number then
    header = header .. "  #" .. cs.pr_number
  end

  local lines, hl = { header, "" }, {}

  if commits and #commits == 1 then
    local c = commits[1]
    table.insert(lines, c.subject)
    if c.body ~= "" then
      table.insert(lines, "")
      vim.list_extend(lines, vim.split(c.body, "\n", { plain = true }))
    end
    table.insert(lines, "")
    table.insert(lines, ("%s  %s"):format(c.author, c.date))
  elseif commits and #commits > 1 then
    for _, c in ipairs(commits) do
      table.insert(lines, c.sha:sub(1, 7) .. "  " .. c.subject)
    end
  end

  if stat and vim.trim(stat) ~= "" then
    table.insert(lines, "")
    -- trimempty (not vim.trim) drops the blank leading/trailing lines a
    -- trailing newline produces WITHOUT touching each stat line's own
    -- leading indent — vim.trim on the whole string stripped only the
    -- FIRST line's leading space (it trims string ends, not per line),
    -- outdenting it by one cell relative to the rest.
    for _, l in ipairs(vim.split(stat, "\n", { plain = true, trimempty = true })) do
      local row = #lines
      table.insert(lines, l)
      for col in l:gmatch("()%+") do
        table.insert(hl, { line = row, col = col - 1, end_col = col, hl_group = "DiffAdd" })
      end
      for col in l:gmatch("()%-") do
        table.insert(hl, { line = row, col = col - 1, end_col = col, hl_group = "DiffDelete" })
      end
    end
  end

  return lines, hl
end

-- Resolve dir peek content asynchronously: `git ls-tree` at the enclosing
-- changeset's head_ref when it names a real ref (stack/stack-tree — the
-- worktree would lie for mid-stack changesets), `fs_scandir` otherwise
-- (uncommitted, or no changeset parent at all — plain tree mode).
---@param item table  outline dir item
---@param docket Review.Docket
---@param callback fun(lines: string[], highlights: table[])
local function dir_content(item, docket, callback)
  local cs_item = enclosing_changeset_item(item)
  local cs = cs_item and cs_item.changeset
  local files = (cs and cs.files) or docket.files
  local changed = {}
  for _, f in ipairs(files) do
    changed[f.path] = f
  end

  local function finish(entries, err)
    if err then
      callback({ "[peek error: " .. err .. "]" }, {})
      return
    end
    callback(M._dir_lines(entries or {}, changed))
  end

  if cs and cs.head_ref and cs.head_ref ~= "WORKTREE" then
    git.ls_tree(docket.cwd, cs.head_ref, item.path, finish)
  else
    local entries = {}
    local fd = vim.uv.fs_scandir(docket.cwd .. "/" .. item.path)
    if fd then
      while true do
        local name, typ = vim.uv.fs_scandir_next(fd)
        if not name then
          break
        end
        table.insert(entries, {
          name = name,
          type = typ == "directory" and "dir" or "file",
          path = item.path .. "/" .. name,
        })
      end
    end
    finish(entries, nil)
  end
end

-- Resolve changeset peek content asynchronously: commits (nil for no-ref
-- changesets) plus a diffstat, then format via `_changeset_lines`.
---@param item table  outline changeset item
---@param docket Review.Docket
---@param callback fun(lines: string[], highlights: table[])
local function changeset_content(item, docket, callback)
  local cs = item.changeset
  local width = 60

  local function with_stat(commits)
    git.stat_range(docket.cwd, cs.base_ref, cs.head_ref, width, function(stat)
      callback(M._changeset_lines(item, commits, stat))
    end)
  end

  if cs.head_ref and cs.head_ref ~= "WORKTREE" then
    git.log_range(docket.cwd, cs.base_ref, cs.head_ref, function(commits)
      with_stat(commits)
    end)
  else
    with_stat(nil)
  end
end

-- Anchor+size the float just to the right of the outline sidebar
-- (overlapping the diff panes) instead of `open_floating_preview`'s default
-- cursor-relative placement. That default sizes the float off the CURRENT
-- window at open time (`nvim_win_get_config(0)` internally clamps width to
-- it) — fine for hovering in a normal-width buffer, but the outline is a
-- fixed ~35-col sidebar, so a cursor-relative float there gets squeezed to
-- sidebar width and wraps every line. Applied via `nvim_win_set_config`
-- AFTER creation rather than by opening from a wider window: switching the
-- current window during the call fires a BufLeave in the wide window's
-- buffer the instant it's left again, which the float's own close-on-
-- BufLeave autocmd (scoped to whatever buffer was current at open time)
-- interprets as "leaving the source buffer" and immediately closes it.
-- Captured synchronously from the outline list window (peek's content
-- arrives async, and by then the cursor may have moved); exposed for tests.
-- Width/height are sized to the actual content (up to a cap and whatever
-- screen room is available) rather than a flat guess — a short dir listing
-- gets a snug float, a wide diffstat gets more room, and either way nothing
-- wraps or gets truncated that didn't need to.
---@param list_win integer  the outline list window, current when peek() was invoked
---@param lines string[]  content lines, for a width/height sized to fit them
---@return {relative: "editor", row: integer, col: integer, width: integer, height: integer, border: string?}?
function M._float_geometry(list_win, lines)
  if not vim.api.nvim_win_is_valid(list_win) then
    return nil
  end
  local cursor_line = vim.api.nvim_win_get_cursor(list_win)[1]
  local screen = vim.fn.screenpos(list_win, cursor_line, 1)
  local win_pos = vim.api.nvim_win_get_position(list_win)
  local col = win_pos[2] + vim.api.nvim_win_get_width(list_win) + 1
  local avail_width = vim.o.columns - col - 2
  if avail_width < 20 then
    return nil
  end
  local content_width = 0
  for _, l in ipairs(lines) do
    content_width = math.max(content_width, vim.fn.strdisplaywidth(l))
  end
  local max_height = vim.o.lines - screen.row - 3
  -- +1 for a cell of breathing room on the right so text doesn't sit flush
  -- against the border.
  return {
    relative = "editor",
    row = screen.row - 1,
    col = col,
    width = math.max(20, math.min(content_width + 1, 100, avail_width)),
    height = math.max(1, math.min(#lines, max_height, 20)),
  }
end

-- Uniformly pad every line with a leading cell rather than relying on each
-- content builder to have left-padded itself (`_dir_lines` does; a
-- changeset header/commit line doesn't) — simpler than conditionally
-- padding only the lines that need it, and every line ends up flush with
-- the same left margin either way. Shifts highlight columns to match.
-- Pure; exposed for unit tests.
---@param lines string[]
---@param highlights {line: integer, col: integer, end_col: integer, hl_group: string}[]
---@return string[] lines
---@return {line: integer, col: integer, end_col: integer, hl_group: string}[] highlights
function M._pad_left(lines, highlights)
  local padded = {}
  for i, l in ipairs(lines) do
    padded[i] = " " .. l
  end
  local shifted = {}
  for i, h in ipairs(highlights) do
    shifted[i] = vim.tbl_extend("force", h, { col = h.col + 1, end_col = h.end_col < 0 and h.end_col or h.end_col + 1 })
  end
  return padded, shifted
end

---@param lines string[]
---@param highlights {line: integer, col: integer, end_col: integer, hl_group: string}[]
---@param list_win integer  the outline list window, current when peek() was invoked
local function open(lines, highlights, list_win)
  lines, highlights = M._pad_left(lines, highlights)
  local bufnr, winid = vim.lsp.util.open_floating_preview(lines, "", {
    focus_id = FOCUS_ID,
    focusable = true,
    border = "rounded",
  })
  if not (winid and vim.api.nvim_win_is_valid(winid)) then
    return
  end
  local geo = M._float_geometry(list_win, lines)
  if geo then
    geo.border = "rounded"
    vim.api.nvim_win_set_config(winid, geo)
  end
  local buf = bufnr or vim.api.nvim_win_get_buf(winid)
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  for _, h in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, NS, h.hl_group, h.line, h.col, h.end_col)
  end
  -- open_floating_preview wires its own `q` to `:bdelete` — that empties the
  -- buffer but does NOT close the floating window (a window always shows
  -- SOME buffer, so deleting the current one just swaps in an empty
  -- scratch buffer, leaving an empty float sitting open). Override `q` to
  -- actually close the window, and mirror the same onto `<Esc>`, so either
  -- dismisses the float from inside it the same way `M.close()` lets the
  -- outline's q/<Esc> dismiss it from outside.
  local function close_this()
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, true)
    end
  end
  vim.keymap.set("n", "q", close_this, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close_this, { buffer = buf, silent = true, nowait = true })
end

-- Close the peek float if one is open. Returns true if it closed something,
-- so callers (the outline's q/<Esc>) can fall through to their own action
-- (closing the review) only when there was no float to dismiss first.
---@return boolean
function M.close()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.w[w][FOCUS_ID] ~= nil and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
      return true
    end
  end
  return false
end

-- Open (or refocus, on a repeat press) the peek float for a dir/changeset
-- row. No-op on file/empty rows — those already have full context in the
-- diff panes.
---@param item table  outline item
---@param docket Review.Docket
function M.peek(item, docket)
  if item.type ~= "dir" and item.type ~= "changeset" then
    return
  end
  -- Captured now (synchronously): peek's content is fetched async, and by
  -- the time it lands the "current window" may no longer be the outline.
  local list_win = vim.api.nvim_get_current_win()
  local function open_here(lines, highlights)
    open(lines, highlights, list_win)
  end
  if item.type == "dir" then
    dir_content(item, docket, open_here)
  else
    changeset_content(item, docket, open_here)
  end
end

return M
