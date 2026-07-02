-- Diff renderer with two layouts.
--
-- Inline: renders the full new file (real buffer content, so treesitter
-- highlighting works), marks added lines with extmarks, and injects deleted
-- lines as virt_lines above their anchor rows.
--
-- Side-by-side: old file in a left scratch buffer, new file in the right one
-- (both real full-file content, so buffer row == lnum - 1 on each side),
-- per-side change highlights, and filler virt_lines keeping visual line-count
-- parity so native scrollbind stays aligned. No :diffthis.
--
-- Context outside hunks is collapsed with manual folds (zR/zM as usual); in
-- side-by-side the fold ranges pair 1:1 by index between panes and open/close
-- state is mirrored.

local M = {}
local signs = require("app.review.ui.signs")
local pair = require("app.review.diff.pair")
local word = require("app.review.diff.word")
local git = require("app.review.diff.git")

local fold_ns = vim.api.nvim_create_namespace("review_fold_gutter")

-- Highlight group tables per render mode: plain = unstaged colors, staged =
-- the dimmer "settled" variants (ui/signs.lua). Attributed rendering picks
-- per line.
local GROUPS_PLAIN = {
  add = "ReviewDiffAdd",
  del = "ReviewDiffDelete",
  add_word = "ReviewDiffAddWord",
  del_word = "ReviewDiffDeleteWord",
  sign_add = "ReviewSignAdd",
  sign_del = "ReviewSignDelete",
  sign_change = "ReviewSignChange",
}
local GROUPS_STAGED = {
  add = "ReviewDiffStagedAdd",
  del = "ReviewDiffStagedDelete",
  add_word = "ReviewDiffStagedAddWord",
  del_word = "ReviewDiffStagedDeleteWord",
  sign_add = "ReviewSignStagedAdd",
  sign_del = "ReviewSignStagedDelete",
  sign_change = "ReviewSignStagedChange",
}

-- Per-line group pickers for a render mode. Attribution rests on coordinate
-- spaces: in the combined (HEAD→WORKTREE) diff, unstaged adds share worktree
-- new_lnum with the combined new side, and staged dels share HEAD old_lnum
-- with the combined old side — membership lookups classify every line, no
-- content matching needed.
---@param mode "plain"|"staged"|"attributed"
---@param file Review.FileChange
---@return fun(new_lnum: integer): table pick_add
---@return fun(old_lnum: integer): table pick_del
local function group_pickers(mode, file)
  if mode == "staged" then
    local staged = function()
      return GROUPS_STAGED
    end
    return staged, staged
  end
  if mode ~= "attributed" then
    local plain = function()
      return GROUPS_PLAIN
    end
    return plain, plain
  end
  local unstaged_add, staged_del = {}, {}
  if file.unstaged then
    for _, hunk in ipairs(file.unstaged.hunks) do
      for _, line in ipairs(hunk.lines) do
        if line.kind == "add" and line.new_lnum then
          unstaged_add[line.new_lnum] = true
        end
      end
    end
  end
  if file.staged_change then
    for _, hunk in ipairs(file.staged_change.hunks) do
      for _, line in ipairs(hunk.lines) do
        if line.kind == "del" and line.old_lnum then
          staged_del[line.old_lnum] = true
        end
      end
    end
  end
  return function(new_lnum)
    return unstaged_add[new_lnum] and GROUPS_PLAIN or GROUPS_STAGED
  end, function(old_lnum)
    return staged_del[old_lnum] and GROUPS_STAGED or GROUPS_PLAIN
  end
end

-- Exposed for unit tests.
M._group_pickers = group_pickers

-- Deleted lines are virt_lines, which are truncated (not wrapped) at the
-- window edge — padding their background fill to a fixed generous width makes
-- the fill window-size independent (no resize watcher needed).
local VIRT_FILL_WIDTH = 500

-- Filler lines (side-by-side): a diagonal ╱ pattern marking rows that exist
-- only in the other pane. One precomputed chunk list; virt_lines truncate at
-- the window edge, so a fixed generous width works like the del fill above.
local FILLER_LINE = { { string.rep("╱", VIRT_FILL_WIDTH), "ReviewDiffFiller" } }

local function filler_vlines(n)
  local out = {}
  for _ = 1, n do
    out[#out + 1] = FILLER_LINE
  end
  return out
end

-- Apply a list of extmark specs {row, col, opts} to a buffer.
-- Coordinates can be out of range when the worktree changed between the diff
-- parse and this render's disk read (hunk-derived cols vs fresh content) —
-- the refresh already underway redraws consistently, so drop the mark rather
-- than abort the render.
local function apply_exts(bufnr, ns, exts)
  for _, e in ipairs(exts) do
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, e.row, e.col, e.opts)
  end
end

-- Compute treesitter highlights for a list of lines with the given filetype.
-- Returns per_line_hl[0-indexed-row] = [{col, end_col, hl_group}].
-- Silently returns {} when no parser is available for ft.
local function ts_highlights_for_lines(lines, ft)
  if not ft or ft == "" or #lines == 0 then
    return {}
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, ft)
  if not ok or not parser then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return {}
  end
  local trees = parser:parse()
  if not trees or not trees[1] then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return {}
  end
  local ok2, query = pcall(vim.treesitter.query.get, ft, "highlights")
  if not ok2 or not query then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return {}
  end
  local hl_cache = {}
  local function resolve_hl(name)
    if hl_cache[name] then
      return hl_cache[name]
    end
    local ft_group = "@" .. name .. "." .. ft
    local group = vim.fn.hlexists(ft_group) == 1 and ft_group or ("@" .. name)
    hl_cache[name] = group
    return group
  end
  local per_line = {}
  for id, node in query:iter_captures(trees[1]:root(), bufnr, 0, -1) do
    local hl_group = resolve_hl(query.captures[id])
    local sr, sc, er, ec = node:range()
    for row = sr, er do
      local line = lines[row + 1] or ""
      local col_s = (row == sr) and sc or 0
      local col_e = (row == er) and ec or #line
      if col_s < col_e then
        per_line[row] = per_line[row] or {}
        table.insert(per_line[row], { col = col_s, end_col = col_e, hl_group = hl_group })
      end
    end
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
  return per_line
end

-- Build virt_line chunks for a deleted line with treesitter and word-diff
-- highlight layers. Extmarks cannot attach to virt_lines, so both layers must
-- be baked into the chunk list:
-- ts_hl: [{col, end_col, hl_group}] treesitter highlights (background layer)
-- wd_hl: [{col, end_col, hl_group}] word-diff highlights (override layer)
-- grp: highlight group table (GROUPS_PLAIN/GROUPS_STAGED)
local function build_virt_chunks(text, ts_hl, wd_hl, grp)
  grp = grp or GROUPS_PLAIN
  local len = #text
  local pts = { [0] = true, [len] = true }
  for _, h in ipairs(ts_hl or {}) do
    if h.col >= 0 and h.end_col <= len and h.end_col > h.col then
      pts[h.col] = true
      pts[h.end_col] = true
    end
  end
  for _, h in ipairs(wd_hl or {}) do
    if h.col >= 0 and h.end_col <= len and h.end_col > h.col then
      pts[h.col] = true
      pts[h.end_col] = true
    end
  end
  local sorted = {}
  for p in pairs(pts) do
    table.insert(sorted, p)
  end
  table.sort(sorted)

  local chunks = {}
  for i = 1, #sorted - 1 do
    local s, e = sorted[i], sorted[i + 1]
    local seg = text:sub(s + 1, e)
    if seg ~= "" then
      -- Word-diff overrides take priority.
      local covered_by_word = false
      for _, h in ipairs(wd_hl or {}) do
        if h.col <= s and h.end_col >= e then
          covered_by_word = true
          break
        end
      end
      if covered_by_word then
        table.insert(chunks, { seg, grp.del_word })
      else
        local ts_group
        for _, h in ipairs(ts_hl or {}) do
          if h.col <= s and h.end_col >= e then
            ts_group = h.hl_group
            break
          end
        end
        -- Combine bg (background) with ts_group (foreground) via multi-group chunk.
        table.insert(chunks, { seg, ts_group and { grp.del, ts_group } or grp.del })
      end
    end
  end
  if #chunks == 0 then
    chunks = { { text, grp.del } }
  end
  local fill = math.max(1, VIRT_FILL_WIDTH - vim.fn.strdisplaywidth(text))
  table.insert(chunks, { string.rep(" ", fill), grp.del })
  return chunks
end

-- Emit the extmarks for one real changed line (add or full-file del):
-- char-level background at priority 100 (word-diff overlays at 1000 override
-- it; never use end_row/line_hl_group for these — they defeat the override),
-- plus a separate EOL mark with hl_eol=true covering text-end → next row so
-- the background fills the window width without any width computation.
-- word_hl (optional) overrides the hl_group baked into word_ranges — the
-- staged variants reuse word.compute's plain-named ranges.
local function emit_line_exts(exts, row, text, bg, sign_hl, word_ranges, word_hl)
  if #text > 0 then
    table.insert(exts, { row = row, col = 0, opts = {
      end_col = #text,
      hl_group = bg,
      priority = 100,
    } })
  end
  table.insert(exts, { row = row, col = #text, opts = {
    end_row = row + 1,
    end_col = 0,
    hl_group = bg,
    hl_eol = true,
    priority = 100,
  } })
  table.insert(exts, { row = row, col = 0, opts = {
    sign_text = "▎",
    sign_hl_group = sign_hl,
    number_hl_group = sign_hl,
  } })
  for _, h in ipairs(word_ranges or {}) do
    table.insert(exts, { row = row, col = h.col, opts = {
      end_col = h.end_col,
      hl_group = word_hl or h.hl_group,
      priority = 1000,
    } })
  end
end

-- Returns the complement of `visible` within [0, total-1] as sorted fold ranges.
-- visible must be sorted and non-overlapping {s,e} pairs (0-indexed inclusive).
local function complement_ranges(visible, total)
  if total == 0 then
    return {}
  end
  local folds = {}
  local cur = 0
  for _, r in ipairs(visible) do
    if cur <= r.s - 1 then
      table.insert(folds, { s = cur, e = r.s - 1 })
    end
    cur = r.e + 1
  end
  if cur <= total - 1 then
    table.insert(folds, { s = cur, e = total - 1 })
  end
  return folds
end

-- Merge a list of possibly-overlapping {s,e} ranges into a sorted disjoint list.
local function merge_ranges(ranges)
  table.sort(ranges, function(a, b)
    return a.s < b.s
  end)
  local out = {}
  for _, r in ipairs(ranges) do
    if #out > 0 and r.s <= out[#out].e + 1 then
      out[#out].e = math.max(out[#out].e, r.e)
    else
      table.insert(out, { s = r.s, e = r.e })
    end
  end
  return out
end

-- Foldtext for collapsed context regions (called via v:lua in the foldtext option).
function M._foldtext()
  local n = vim.v.foldend - vim.v.foldstart + 1
  return { { string.format("  ┄ %d lines ┄", n), "Folded" } }
end

---@class Review.RowInfo
---@field lnum integer
---@field side "LEFT"|"RIGHT"
---@field text string

---@class Review.HunkRows
---@field s integer          -- 0-indexed first buffer row of the hunk
---@field e integer          -- 0-indexed last buffer row of the hunk
---@field first_diff integer -- first row that is an add or a del anchor
---@field last_diff integer

---@class Review.DiffView
---@field bufnr integer       right pane: the new file (the only pane inline)
---@field bufnr_left integer  left pane: the old file (side-by-side only)
---@field win integer         primary window; nav/cursor ops live here
---@field win_left integer?   bound while layout == "sbs"
---@field layout "inline"|"sbs"
---@field file Review.FileChange?
---@field hunk_rows Review.HunkRows[]       ordered top-to-bottom; nav anchors
---@field hunk_rows_left Review.HunkRows[]  left-pane counterpart (sbs)
---@field _cwd string
---@field _render_seq integer
---@field _render_mode "plain"|"staged"|"attributed"
---@field _sorted_hunks Review.Hunk[]?  hunks in render order (hunk_at targets)
---@field _rendered_file Review.FileChange?  set when an async render completes; staging ops require it to match the plan
---@field _row_map table<integer, Review.RowInfo>
---@field _fold_ranges {s:integer,e:integer}[]
---@field _fold_ranges_left {s:integer,e:integer}[]
---@field _fold_aug integer?
---@field _fold_sync fun(win: integer)?  set while sbs fold sync is active
local DiffView = {}
DiffView.__index = DiffView

local function new_scratch_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "review-diff"
  return bufnr
end

local function apply_win_opts(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].number = true
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "yes"
    vim.wo[win].foldcolumn = "1"
    vim.wo[win].conceallevel = 0
    vim.wo[win].wrap = false
  end
end

---@param opts {win: integer}
---@return Review.DiffView
function M.new(opts)
  local self = setmetatable({}, DiffView)
  self.win = opts.win
  self.win_left = nil
  self.layout = "inline"
  self.file = nil
  self.hunk_rows = {}
  self.hunk_rows_left = {}
  self._cwd = ""
  self._render_seq = 0
  self._render_mode = "plain"
  self._row_map = {}
  self._fold_ranges = {}
  self._fold_ranges_left = {}

  self.bufnr = new_scratch_buf()
  self.bufnr_left = new_scratch_buf()
  apply_win_opts(self.win)
  self:_setup_fold_keymaps()

  return self
end

-- Fold commands that change open/close state without moving the cursor or
-- scrolling (zc, zR, ...) fire no autocmd, so the mask-diff sync in
-- _setup_fold_sync never sees them. Remap them buffer-locally to run the
-- native command and then sync immediately. The maps are installed once per
-- pane buffer; when sync is inactive (inline layout) _fold_sync is nil and
-- the remap is just the native command.
local FOLD_KEYS = { "za", "zA", "zo", "zO", "zc", "zC", "zv", "zx", "zX", "zr", "zm", "zR", "zM" }

function DiffView:_setup_fold_keymaps()
  for _, bufnr in ipairs({ self.bufnr, self.bufnr_left }) do
    for _, key in ipairs(FOLD_KEYS) do
      vim.keymap.set("n", key, function()
        -- Counts select fold levels; these are all depth-1 folds, so no
        -- count forwarding. E490 (no fold found) on foldless lines; native
        -- keys just echo it — and a failed command can't have changed state.
        if pcall(vim.cmd, "normal! " .. key) then
          self:sync_folds(vim.api.nvim_get_current_win())
        end
      end, { buffer = bufnr, silent = true, desc = "Fold (synced across panes)" })
    end
  end
end

-- Re-run pane fold sync after an API-context fold change (e.g. `normal! zv`
-- following nvim_win_set_cursor — no autocmd fires). No-op unless sbs sync
-- is active.
---@param win integer?
function DiffView:sync_folds(win)
  if self._fold_sync then
    self._fold_sync(win or self.win)
  end
end

-- Move the cursor to a line, open its enclosing folds, and re-sync pane fold
-- state. API-context navigation must reveal through this method — a bare
-- `normal! zv` fires no autocmd, so the panes would desync.
---@param win integer
---@param lnum integer  1-based target line
function DiffView:reveal(win, lnum)
  vim.api.nvim_win_set_cursor(win, { lnum, 0 })
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! zv")
  end)
  self:sync_folds(win)
end

-- Bind (or rebind) the primary window — used when the docket creates the
-- staged row for this instance after construction.
---@param win integer
function DiffView:bind_primary(win)
  self.win = win
  apply_win_opts(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_buf(win, self.bufnr)
  end
end

function DiffView:_clear_fold_sync()
  if self._fold_aug then
    vim.api.nvim_del_augroup_by_id(self._fold_aug)
    self._fold_aug = nil
  end
  self._fold_sync = nil
end

-- Switch layouts. Entering sbs binds win_left (a window created by the
-- caller) and shows the old-side buffer there; leaving clears the binding
-- and sync state (the caller closes the window).
---@param layout "inline"|"sbs"
---@param win_left integer?
function DiffView:set_layout(layout, win_left)
  self:_clear_fold_sync()
  self.layout = layout
  if layout == "sbs" then
    self.win_left = win_left
    apply_win_opts(win_left)
    if win_left and vim.api.nvim_win_is_valid(win_left) then
      -- Blank the old-side buffer so the pane never shows a previously
      -- rendered file's stale content while the async render is in flight.
      self:_write(self.bufnr_left, {})
      vim.api.nvim_win_set_buf(win_left, self.bufnr_left)
    end
  else
    for _, win in ipairs({ self.win, self.win_left }) do
      if win and vim.api.nvim_win_is_valid(win) then
        vim.wo[win].scrollbind = false
      end
    end
    self.win_left = nil
  end
end

-- Write lines to a buffer (clears its signs namespace).
function DiffView:_write(bufnr, lines)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  signs.clear(bufnr)
end

function DiffView:_set_ft(bufnr, path)
  local ft = vim.filetype.match({ filename = path }) or ""
  if ft ~= "" and ft ~= vim.bo[bufnr].filetype then
    vim.bo[bufnr].filetype = ft
  end
  return ft
end

function DiffView:_show()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_buf(self.win, self.bufnr)
  end
  if self.layout == "sbs" and self.win_left and vim.api.nvim_win_is_valid(self.win_left) then
    vim.api.nvim_win_set_buf(self.win_left, self.bufnr_left)
  end
end

function DiffView:_render_placeholder(msg)
  -- The rewrite drops the buffers' manual folds; a live sync closure would
  -- keep scanning fold ranges that no longer exist.
  self:_clear_fold_sync()
  self:_write(self.bufnr, { msg })
  self.hunk_rows = {}
  self._row_map = {}
  if self.layout == "sbs" then
    self:_write(self.bufnr_left, {})
    self.hunk_rows_left = {}
  end
  self:_show()
end

-- Resolve the source line info for a 0-indexed buffer row (comments/M5 hook).
---@param row integer
---@return Review.RowInfo?
function DiffView:row_to_source(row)
  return self._row_map[row]
end

-- Fold ranges: the complement of the hunk row ranges.
local function compute_folds(hunk_rows, total)
  if #hunk_rows == 0 then
    return {}
  end
  local vis = {}
  for _, hr in ipairs(hunk_rows) do
    table.insert(vis, { s = hr.s, e = hr.e })
  end
  return complement_ranges(merge_ranges(vis), total)
end

-- Apply fold ranges to one window. Window-local manual folds; the global
-- foldmethod=expr from the default app's folding plugin is per-window
-- overridden here.
local function do_fold(win, bufnr, folds)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, fold_ns, 0, -1)
  vim.api.nvim_win_call(win, function()
    vim.wo[win][0].foldmethod = "manual"
    vim.wo[win][0].foldenable = true
    vim.wo[win][0].foldlevel = 0
    vim.wo[win][0].foldtext = "v:lua.require'app.review.ui.diff'._foldtext()"
    vim.cmd("normal! zE")
    for _, r in ipairs(folds) do
      if r.s <= r.e then
        vim.api.nvim_buf_set_extmark(bufnr, fold_ns, r.s, 0, {
          number_hl_group = "Folded",
        })
        vim.cmd(string.format("%d,%dfold", r.s + 1, r.e + 1))
      end
    end
  end)
end

-- Fold everything outside hunk row ranges (both panes in side-by-side).
function DiffView:_apply_folds()
  self._fold_ranges = compute_folds(self.hunk_rows, vim.api.nvim_buf_line_count(self.bufnr))
  do_fold(self.win, self.bufnr, self._fold_ranges)
  if self.layout == "sbs" then
    self._fold_ranges_left = compute_folds(self.hunk_rows_left, vim.api.nvim_buf_line_count(self.bufnr_left))
    do_fold(self.win_left, self.bufnr_left, self._fold_ranges_left)
    self:_setup_fold_sync()
  end
end

-- Mirror fold open/close state between the side-by-side panes. Fold ranges
-- pair 1:1 by index (inter-hunk context has equal line counts on both
-- sides), so no row translation is needed. Triggers: the buffer-local fold
-- key remaps (deterministic, covers in-place zc/zR), sync_folds (API-context
-- changes), plus WinScrolled/CursorMoved as a safety net for anything else
-- that shifts fold state.
function DiffView:_setup_fold_sync()
  self:_clear_fold_sync()
  local win_r, win_l = self.win, self.win_left
  local fr, fl = self._fold_ranges, self._fold_ranges_left
  if not (win_l and vim.api.nvim_win_is_valid(win_l) and vim.api.nvim_win_is_valid(win_r)) then
    return
  end
  -- Degenerate hunk geometry (0-count hunks at file edges) can merge a gap
  -- on one side only; without 1:1 pairing the mirror would misfold.
  if #fr == 0 or #fr ~= #fl then
    return
  end

  local syncing = false

  -- mask[i] = true when folds[i] is currently open in win. One win_call for
  -- the whole scan — this runs from CursorMoved, so per-fold round-trips add up.
  local function open_mask(win, folds)
    return vim.api.nvim_win_call(win, function()
      local mask = {}
      for i, f in ipairs(folds) do
        mask[i] = vim.fn.foldclosed(f.s + 1) == -1
      end
      return mask
    end)
  end

  local function apply_mask(win, folds, mask)
    vim.api.nvim_win_call(win, function()
      for i, f in ipairs(folds) do
        local closed = vim.fn.foldclosed(f.s + 1) ~= -1
        if mask[i] and closed then
          vim.cmd(string.format("%d,%dfoldopen", f.s + 1, f.e + 1))
        elseif not mask[i] and not closed then
          vim.cmd(string.format("%d,%dfoldclose", f.s + 1, f.e + 1))
        end
      end
    end)
  end

  local function masks_equal(m1, m2)
    for i = 1, #m1 do
      if m1[i] ~= m2[i] then
        return false
      end
    end
    return true
  end

  -- do_fold just applied everything closed; no need to scan for the snapshot.
  local last_mask_r, last_mask_l = {}, {}
  for i = 1, #fr do
    last_mask_r[i], last_mask_l[i] = false, false
  end

  -- Mirror `mask` (freshly read from one side) onto the other side. After a
  -- successful mirror both sides equal the applied mask by construction.
  local function sync(mask, to_win, to_folds)
    syncing = true
    -- E490: folds deleted out-of-band (zE/zd fire no autocmd) — nothing to
    -- mirror, and `syncing` must reset or every later sync no-ops.
    pcall(apply_mask, to_win, to_folds, mask)
    syncing = false
    last_mask_r, last_mask_l = mask, mask
  end

  local function on_event(win)
    if syncing or not (vim.api.nvim_win_is_valid(win_r) and vim.api.nvim_win_is_valid(win_l)) then
      return
    end
    -- zi (nofoldenable) makes foldclosed() read -1 everywhere; syncing that
    -- all-open mask would genuinely open the other pane's folds.
    if not (vim.wo[win_r].foldenable and vim.wo[win_l].foldenable) then
      return
    end
    if win == win_r then
      local mask = open_mask(win_r, fr)
      if not masks_equal(mask, last_mask_r) then
        sync(mask, win_l, fl)
      end
    elseif win == win_l then
      local mask = open_mask(win_l, fl)
      if not masks_equal(mask, last_mask_l) then
        sync(mask, win_r, fr)
      end
    end
  end

  self._fold_sync = on_event
  self._fold_aug = vim.api.nvim_create_augroup("ReviewFoldSync_" .. win_r, { clear = true })
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = self._fold_aug,
    callback = function(ev)
      on_event(tonumber(ev.match))
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self._fold_aug,
    callback = function()
      on_event(vim.api.nvim_get_current_win())
    end,
  })
end

-- Load old- and new-side content for a file. git.show may call back
-- synchronously (WORKTREE reads from disk), so guard against double-finish.
local function load_both(file, cwd, cb)
  local base = file.base_ref or "HEAD"
  local head = file.head_ref or "WORKTREE"
  local old_lines, new_lines
  local done = false
  local function finish()
    if done or not (old_lines and new_lines) then
      return
    end
    done = true
    cb(old_lines, new_lines)
  end

  if file.status == "A" or file.status == "U" then
    old_lines = {}
  else
    git.show(cwd, base, file.old_path or file.path, function(content, _)
      old_lines = content and vim.split(content, "\n", { plain = true }) or {}
      finish()
    end)
  end

  if file.status == "D" then
    new_lines = {}
  else
    git.show(cwd, head, file.path, function(content, _)
      new_lines = content and vim.split(content, "\n", { plain = true }) or {}
      finish()
    end)
  end

  finish()
end

---@param file Review.FileChange
---@param cwd string
---@param on_done? fun()  called after the buffer is rendered and folds applied
---@param mode? "plain"|"staged"|"attributed"  highlight attribution (default "plain")
function DiffView:render(file, cwd, on_done, mode)
  self.file = file
  self._cwd = cwd
  self._render_mode = mode or "plain"
  self._render_seq = self._render_seq + 1
  local seq = self._render_seq

  if file.status == "B" then
    self:_render_placeholder("[Binary file: " .. file.path .. "]")
    if on_done then on_done() end
    return
  end

  load_both(file, cwd, function(old_lines, new_lines)
    if self._render_seq ~= seq or not vim.api.nvim_buf_is_valid(self.bufnr) then
      return
    end
    -- Fall back to inline when the left window vanished out-of-band (:q in
    -- the pane); the next toggle re-syncs the docket's layout state.
    if self.layout == "sbs" and self.win_left and vim.api.nvim_win_is_valid(self.win_left) then
      self:_render_sbs(file, old_lines, new_lines)
    else
      self:_render_inline(file, old_lines, new_lines)
    end
    if on_done then on_done() end
  end)
end

---@param file Review.FileChange
---@param old_lines string[]
---@param new_lines string[]
function DiffView:_render_inline(file, old_lines, new_lines)
  local exts = {}
  local row_map = {}
  local pick_add, pick_del = group_pickers(self._render_mode, file)

  if file.status == "D" then
    -- Deleted file: show the old content, every line marked deleted.
    self:_write(self.bufnr, old_lines)
    self:_set_ft(self.bufnr, file.old_path or file.path)
    for i = 1, #old_lines do
      local row = i - 1
      local grp = pick_del(i)
      row_map[row] = { lnum = i, side = "LEFT", text = old_lines[i] }
      emit_line_exts(exts, row, old_lines[i], grp.del, grp.sign_del, nil)
    end
    apply_exts(self.bufnr, signs.ns, exts)
    self._row_map = row_map
    local last = math.max(0, #old_lines - 1)
    self.hunk_rows = { { s = 0, e = last, first_diff = 0, last_diff = last } }
    self._sorted_hunks = file.hunks
    self:_show()
    self:_apply_folds()
    self._rendered_file = file
    return
  end

  -- Shallow copy for the sort — table.sort only reorders the outer list.
  local sorted = {}
  for i, h in ipairs(file.hunks) do
    sorted[i] = h
  end
  table.sort(sorted, function(a, b)
    return a.new_start < b.new_start
  end)

  local ft = vim.filetype.match({ filename = file.path }) or ""
  -- Treesitter highlights for old_lines (syntax-colors the del virt_lines).
  local ts_hl_map = ts_highlights_for_lines(old_lines, ft)

  -- Per-lnum annotation maps built from hunk segments.
  local add_set = {}      -- new_lnum → true
  local change_set = {}   -- new_lnum → true (paired change, not pure add)
  local add_word = {}     -- new_lnum → [{col,end_col,hl_group}]
  local del_virts = {}    -- anchor new_lnum → list of virt_line chunk lists
  local del_sign_hl = {}  -- anchor new_lnum → sign group for the pure-del marker

  for _, hunk in ipairs(sorted) do
    local segs = pair.segments(hunk.lines)
    for si, seg in ipairs(segs) do
      if seg.type == "change" then
        local n_pair = math.min(#seg.dels, #seg.adds)
        local wdiffs = {}
        for j = 1, n_pair do
          wdiffs[j] = word.compute(seg.adds[j].text, seg.dels[j].text)
        end

        -- Anchor for del virt_lines: the first paired add line, else the next
        -- context line, else past-the-end (trailing).
        local anchor_lnum
        if #seg.adds > 0 then
          anchor_lnum = seg.adds[1].new_lnum
        else
          local next_seg = segs[si + 1]
          if next_seg and next_seg.type == "ctx" and #next_seg.lines > 0 then
            anchor_lnum = next_seg.lines[1].new_lnum
          else
            anchor_lnum = #new_lines + 1
          end
        end

        del_virts[anchor_lnum] = del_virts[anchor_lnum] or {}
        for j, dl in ipairs(seg.dels) do
          local wd = wdiffs[j]
          local grp = pick_del(dl.old_lnum)
          if not del_sign_hl[anchor_lnum] then
            del_sign_hl[anchor_lnum] = grp.sign_del
          end
          table.insert(
            del_virts[anchor_lnum],
            build_virt_chunks(dl.text, ts_hl_map[dl.old_lnum - 1], wd and wd.removed, grp)
          )
        end

        for j, al in ipairs(seg.adds) do
          add_set[al.new_lnum] = true
          if j <= n_pair then
            change_set[al.new_lnum] = true
          end
          local wd = wdiffs[j]
          if wd then
            add_word[al.new_lnum] = wd.added
          end
        end
      end
    end
  end

  -- Write the new file and annotate it.
  self:_write(self.bufnr, new_lines)
  self:_set_ft(self.bufnr, file.path)

  for lnum = 1, #new_lines do
    local row = lnum - 1
    row_map[row] = { lnum = lnum, side = "RIGHT", text = new_lines[lnum] }

    if del_virts[lnum] then
      table.insert(exts, { row = row, col = 0, opts = {
        virt_lines = del_virts[lnum],
        virt_lines_above = true,
      } })
      -- Pure-del anchor (context line): mark the line above the virt dels,
      -- which is the visual top (virt_lines_above renders above the anchor).
      if not add_set[lnum] and row > 0 then
        local sign = del_sign_hl[lnum] or "ReviewSignDelete"
        table.insert(exts, { row = row - 1, col = 0, opts = {
          sign_text = "▾",
          sign_hl_group = sign,
          number_hl_group = sign,
        } })
      end
    end

    if add_set[lnum] then
      local grp = pick_add(lnum)
      local sign_hl = change_set[lnum] and grp.sign_change or grp.sign_add
      emit_line_exts(exts, row, new_lines[lnum], grp.add, sign_hl, add_word[lnum], grp.add_word)
    end
  end

  -- Trailing del virts (anchor beyond the last line).
  local trailing_anchor = #new_lines + 1
  if del_virts[trailing_anchor] then
    local last_row = math.max(0, #new_lines - 1)
    table.insert(exts, { row = last_row, col = 0, opts = {
      virt_lines = del_virts[trailing_anchor],
      virt_lines_above = false,
    } })
  end

  apply_exts(self.bufnr, signs.ns, exts)
  self._row_map = row_map

  -- Hunk row ranges (row = new_lnum - 1). first_diff/last_diff: first/last
  -- row that is an add or a del anchor — nav targets.
  local hunk_rows = {}
  for _, hunk in ipairs(sorted) do
    if hunk.new_count > 0 then
      local hs = hunk.new_start - 1
      local he = hunk.new_start + hunk.new_count - 2
      local fd, ld = nil, nil
      for lnum = hunk.new_start, hunk.new_start + hunk.new_count - 1 do
        if add_set[lnum] then
          if not fd then fd = lnum - 1 end
          ld = lnum - 1
        elseif del_virts[lnum] then
          -- Del virts render above the anchor; the visual top is row-1.
          if not fd and lnum - 2 >= hs then fd = lnum - 2 end
        end
      end
      table.insert(hunk_rows, { s = hs, e = he, first_diff = fd or hs, last_diff = ld or he })
    else
      -- Pure-del hunk: anchor is the row where the del virts appear.
      local anchor = math.min(hunk.new_start - 1, math.max(0, #new_lines - 1))
      anchor = math.max(0, anchor)
      table.insert(hunk_rows, { s = anchor, e = anchor, first_diff = anchor, last_diff = anchor })
    end
  end
  self.hunk_rows = hunk_rows
  self._sorted_hunks = sorted

  self:_show()
  self:_apply_folds()
  self._rendered_file = file
end

-- The hunk under a 0-indexed buffer row in the given window, in the same
-- order the renderer used — staging ops resolve their target through this
-- (returning the hunk object avoids the index-must-match-sort invariant).
---@param win integer
---@param row integer
---@return Review.Hunk?
function DiffView:hunk_at(win, row)
  local rows = (win == self.win_left) and self.hunk_rows_left or self.hunk_rows
  for i, hr in ipairs(rows) do
    if row >= hr.s and row <= hr.e then
      return self._sorted_hunks and self._sorted_hunks[i] or nil
    end
  end
end

-- Annotation walk for the side-by-side layout. Buffer contents are exactly
-- old_lines (left) and new_lines (right), so buffer row == lnum - 1 on each
-- side and only the decoration data is computed here. Exposed for unit tests.
--
-- Fillers keep visual line-count parity per change segment: the side with
-- fewer real lines gets |n_del - n_add| filler virt_lines anchored below its
-- last segment row. A negative anchor (segment at the top of the file) lands
-- above row 0 when the side has content, keeping line 1 top-aligned; an
-- empty side anchors below its single blank row instead.
---@param hunks Review.Hunk[]  sorted by old_start
---@param old_lines string[]
---@param new_lines string[]
---@param pickers? {pick_add: fun(new_lnum: integer): table, pick_del: fun(old_lnum: integer): table}
---@return {exts_l: table[], exts_r: table[], fillers_l: {row:integer,count:integer,above:boolean}[], fillers_r: {row:integer,count:integer,above:boolean}[], hunk_rows_l: Review.HunkRows[], hunk_rows_r: Review.HunkRows[]}
function M._sbs_annotations(hunks, old_lines, new_lines, pickers)
  local plain = function(_)
    return GROUPS_PLAIN
  end
  local pick_add = pickers and pickers.pick_add or plain
  local pick_del = pickers and pickers.pick_del or plain
  local exts_l, exts_r = {}, {}
  local fillers_l, fillers_r = {}, {}
  local hunk_rows_l, hunk_rows_r = {}, {}

  local function filler(list, row, count, side_has_lines)
    local above = false
    if row < 0 then
      row = 0
      above = side_has_lines
    end
    table.insert(list, { row = row, count = count, above = above })
  end

  -- Hunk row range for one side; a 0-count side collapses to an anchor row.
  local function rows_entry(start, count, total, fd, ld)
    if count > 0 then
      local s, e = start - 1, start + count - 2
      return { s = s, e = e, first_diff = fd or s, last_diff = ld or e }
    end
    local anchor = math.max(0, math.min(start - 1, total - 1))
    return { s = anchor, e = anchor, first_diff = anchor, last_diff = anchor }
  end

  for _, hunk in ipairs(hunks) do
    -- o/n: next unprocessed lnum per side. A 0-count side has start = the
    -- line *before* the change (unified-diff convention), so bump it.
    local o = hunk.old_count == 0 and hunk.old_start + 1 or hunk.old_start
    local n = hunk.new_count == 0 and hunk.new_start + 1 or hunk.new_start
    local fd_l, ld_l, fd_r, ld_r

    for _, seg in ipairs(pair.segments(hunk.lines)) do
      if seg.type == "ctx" then
        o = o + #seg.lines
        n = n + #seg.lines
      else
        local n_del, n_add = #seg.dels, #seg.adds
        local n_pair = math.min(n_del, n_add)
        local wdiffs = {}
        for j = 1, n_pair do
          wdiffs[j] = word.compute(seg.adds[j].text, seg.dels[j].text)
        end

        for j, dl in ipairs(seg.dels) do
          local row = dl.old_lnum - 1
          local wd = wdiffs[j]
          local grp = pick_del(dl.old_lnum)
          local sign = j <= n_pair and grp.sign_change or grp.sign_del
          emit_line_exts(exts_l, row, dl.text, grp.del, sign, wd and wd.removed, grp.del_word)
          fd_l = fd_l or row
          ld_l = row
        end
        for j, al in ipairs(seg.adds) do
          local row = al.new_lnum - 1
          local wd = wdiffs[j]
          local grp = pick_add(al.new_lnum)
          local sign = j <= n_pair and grp.sign_change or grp.sign_add
          emit_line_exts(exts_r, row, al.text, grp.add, sign, wd and wd.added, grp.add_word)
          fd_r = fd_r or row
          ld_r = row
        end

        if n_add > n_del then
          filler(fillers_l, o + n_del - 2, n_add - n_del, #old_lines > 0)
        elseif n_del > n_add then
          filler(fillers_r, n + n_add - 2, n_del - n_add, #new_lines > 0)
        end
        o = o + n_del
        n = n + n_add
      end
    end

    table.insert(hunk_rows_l, rows_entry(hunk.old_start, hunk.old_count, #old_lines, fd_l, ld_l))
    table.insert(hunk_rows_r, rows_entry(hunk.new_start, hunk.new_count, #new_lines, fd_r, ld_r))
  end

  return {
    exts_l = exts_l,
    exts_r = exts_r,
    fillers_l = fillers_l,
    fillers_r = fillers_r,
    hunk_rows_l = hunk_rows_l,
    hunk_rows_r = hunk_rows_r,
  }
end

---@param file Review.FileChange
---@param old_lines string[]
---@param new_lines string[]
function DiffView:_render_sbs(file, old_lines, new_lines)
  self:_write(self.bufnr, new_lines)
  self:_write(self.bufnr_left, old_lines)
  self:_set_ft(self.bufnr, file.path)
  self:_set_ft(self.bufnr_left, file.old_path or file.path)

  -- Shallow copy for the sort — table.sort only reorders the outer list.
  local sorted = {}
  for i, h in ipairs(file.hunks) do
    sorted[i] = h
  end
  table.sort(sorted, function(a, b)
    return a.old_start < b.old_start
  end)
  self._sorted_hunks = sorted
  local pick_add, pick_del = group_pickers(self._render_mode, file)
  local ann = M._sbs_annotations(sorted, old_lines, new_lines, { pick_add = pick_add, pick_del = pick_del })

  local function add_filler_exts(exts, fillers)
    for _, f in ipairs(fillers) do
      table.insert(exts, { row = f.row, col = 0, opts = {
        virt_lines = filler_vlines(f.count),
        virt_lines_above = f.above,
      } })
    end
  end
  add_filler_exts(ann.exts_l, ann.fillers_l)
  add_filler_exts(ann.exts_r, ann.fillers_r)
  apply_exts(self.bufnr_left, signs.ns, ann.exts_l)
  apply_exts(self.bufnr, signs.ns, ann.exts_r)

  local row_map = {}
  for i = 1, #new_lines do
    row_map[i - 1] = { lnum = i, side = "RIGHT", text = new_lines[i] }
  end
  self._row_map = row_map
  self.hunk_rows = ann.hunk_rows_r
  self.hunk_rows_left = ann.hunk_rows_l

  self:_show()
  self:_apply_folds()
  -- Bind, align both panes at the top, and capture the scrollbind offset (0).
  for _, win in ipairs({ self.win, self.win_left }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.wo[win].scrollbind = true
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
    end
  end
  -- syncbind is relative to the current window, which may be the outline or
  -- another tab entirely (async render off the save watcher) — anchor it.
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_call(self.win, function()
      vim.cmd("syncbind")
    end)
  end
  self._rendered_file = file
end

function DiffView:destroy()
  word.clear_cache()
  self:_clear_fold_sync()
  -- Close the sbs split so a re-opened review doesn't inherit a dead pane.
  -- pcall: closing can throw when it is the last window in the tab.
  if self.win_left and vim.api.nvim_win_is_valid(self.win_left) then
    pcall(vim.api.nvim_win_close, self.win_left, true)
  end
  self.win_left = nil
  for _, bufnr in ipairs({ self.bufnr, self.bufnr_left }) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
end

return M
