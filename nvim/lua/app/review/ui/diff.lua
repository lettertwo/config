-- Inline diff renderer. Renders the full new file (real buffer content, so
-- treesitter highlighting works), marks added lines with extmarks, and injects
-- deleted lines as virt_lines above their anchor rows. Context outside hunks
-- is collapsed with manual folds (zR/zM open/close as usual).
--
-- Side-by-side rendering arrives in M4; row maps stay side-aware ({lnum, side})
-- so the second pane is additive.

local M = {}
local signs = require("app.review.ui.signs")
local pair = require("app.review.diff.pair")
local word = require("app.review.diff.word")
local git = require("app.review.diff.git")

local fold_ns = vim.api.nvim_create_namespace("review_fold_gutter")

-- Deleted lines are virt_lines, which are truncated (not wrapped) at the
-- window edge — padding their background fill to a fixed generous width makes
-- the fill window-size independent (no resize watcher needed).
local VIRT_FILL_WIDTH = 500

-- Apply a list of extmark specs {row, col, opts} to a buffer.
local function apply_exts(bufnr, ns, exts)
  for _, e in ipairs(exts) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, e.row, e.col, e.opts)
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
local function build_virt_chunks(text, ts_hl, wd_hl)
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
        table.insert(chunks, { seg, "ReviewDiffDeleteWord" })
      else
        local ts_group
        for _, h in ipairs(ts_hl or {}) do
          if h.col <= s and h.end_col >= e then
            ts_group = h.hl_group
            break
          end
        end
        -- Combine bg (background) with ts_group (foreground) via multi-group chunk.
        table.insert(chunks, { seg, ts_group and { "ReviewDiffDelete", ts_group } or "ReviewDiffDelete" })
      end
    end
  end
  if #chunks == 0 then
    chunks = { { text, "ReviewDiffDelete" } }
  end
  local fill = math.max(1, VIRT_FILL_WIDTH - vim.fn.strdisplaywidth(text))
  table.insert(chunks, { string.rep(" ", fill), "ReviewDiffDelete" })
  return chunks
end

-- Emit the extmarks for one real changed line (add or full-file del):
-- char-level background at priority 100 (word-diff overlays at 1000 override
-- it; never use end_row/line_hl_group for these — they defeat the override),
-- plus a separate EOL mark with hl_eol=true covering text-end → next row so
-- the background fills the window width without any width computation.
local function emit_line_exts(exts, row, text, bg, sign_hl, word_ranges)
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
      hl_group = h.hl_group,
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
---@field bufnr integer
---@field win integer
---@field file Review.FileChange?
---@field hunk_rows Review.HunkRows[]  ordered top-to-bottom; nav anchors
---@field _cwd string
---@field _render_seq integer
---@field _row_map table<integer, Review.RowInfo>
local DiffView = {}
DiffView.__index = DiffView

---@param opts {win: integer}
---@return Review.DiffView
function M.new(opts)
  local self = setmetatable({}, DiffView)
  self.win = opts.win
  self.file = nil
  self.hunk_rows = {}
  self._cwd = ""
  self._render_seq = 0
  self._row_map = {}

  self.bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[self.bufnr].buftype = "nofile"
  vim.bo[self.bufnr].bufhidden = "hide"
  vim.bo[self.bufnr].swapfile = false
  vim.bo[self.bufnr].modifiable = false
  vim.bo[self.bufnr].filetype = "review-diff"

  if vim.api.nvim_win_is_valid(self.win) then
    vim.wo[self.win].number = true
    vim.wo[self.win].relativenumber = false
    vim.wo[self.win].signcolumn = "yes"
    vim.wo[self.win].foldcolumn = "1"
    vim.wo[self.win].conceallevel = 0
    vim.wo[self.win].wrap = false
  end

  return self
end

-- Write lines to the buffer (clears the signs namespace).
function DiffView:_write(lines)
  vim.bo[self.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  vim.bo[self.bufnr].modifiable = false
  signs.clear(self.bufnr)
end

function DiffView:_set_ft(path)
  local ft = vim.filetype.match({ filename = path }) or ""
  if ft ~= "" and ft ~= vim.bo[self.bufnr].filetype then
    vim.bo[self.bufnr].filetype = ft
  end
  return ft
end

function DiffView:_show()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_buf(self.win, self.bufnr)
  end
end

function DiffView:_render_placeholder(msg)
  self:_write({ msg })
  self.hunk_rows = {}
  self._row_map = {}
  self:_show()
end

-- Resolve the source line info for a 0-indexed buffer row (comments/M5 hook).
---@param row integer
---@return Review.RowInfo?
function DiffView:row_to_source(row)
  return self._row_map[row]
end

-- Fold everything outside hunk row ranges. Window-local manual folds; the
-- global foldmethod=expr from the default app's folding plugin is per-window
-- overridden here.
function DiffView:_apply_folds()
  if not vim.api.nvim_win_is_valid(self.win) then
    return
  end
  local total = vim.api.nvim_buf_line_count(self.bufnr)
  local folds = {}
  if #self.hunk_rows > 0 then
    local vis = {}
    for _, hr in ipairs(self.hunk_rows) do
      table.insert(vis, { s = hr.s, e = hr.e })
    end
    folds = complement_ranges(merge_ranges(vis), total)
  end
  vim.api.nvim_buf_clear_namespace(self.bufnr, fold_ns, 0, -1)
  vim.api.nvim_win_call(self.win, function()
    vim.wo[self.win][0].foldmethod = "manual"
    vim.wo[self.win][0].foldenable = true
    vim.wo[self.win][0].foldlevel = 0
    vim.wo[self.win][0].foldtext = "v:lua.require'app.review.ui.diff'._foldtext()"
    vim.cmd("normal! zE")
    for _, r in ipairs(folds) do
      if r.s <= r.e then
        vim.api.nvim_buf_set_extmark(self.bufnr, fold_ns, r.s, 0, {
          number_hl_group = "Folded",
        })
        vim.cmd(string.format("%d,%dfold", r.s + 1, r.e + 1))
      end
    end
  end)
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
function DiffView:render(file, cwd, on_done)
  self.file = file
  self._cwd = cwd
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
    self:_render_inline(file, old_lines, new_lines)
    if on_done then on_done() end
  end)
end

---@param file Review.FileChange
---@param old_lines string[]
---@param new_lines string[]
function DiffView:_render_inline(file, old_lines, new_lines)
  local exts = {}
  local row_map = {}

  if file.status == "D" then
    -- Deleted file: show the old content, every line marked deleted.
    self:_write(old_lines)
    self:_set_ft(file.old_path or file.path)
    for i = 1, #old_lines do
      local row = i - 1
      row_map[row] = { lnum = i, side = "LEFT", text = old_lines[i] }
      emit_line_exts(exts, row, old_lines[i], "ReviewDiffDelete", "ReviewSignDelete", nil)
    end
    apply_exts(self.bufnr, signs.ns, exts)
    self._row_map = row_map
    local last = math.max(0, #old_lines - 1)
    self.hunk_rows = { { s = 0, e = last, first_diff = 0, last_diff = last } }
    self:_show()
    self:_apply_folds()
    return
  end

  local sorted = vim.deepcopy(file.hunks)
  table.sort(sorted, function(a, b)
    return a.new_start < b.new_start
  end)

  local ft = vim.filetype.match({ filename = file.path }) or ""
  -- Treesitter highlights for old_lines (syntax-colors the del virt_lines).
  local ts_hl_map = ts_highlights_for_lines(old_lines, ft)

  -- Per-lnum annotation maps built from hunk segments.
  local add_set = {}    -- new_lnum → true
  local change_set = {} -- new_lnum → true (paired change, not pure add)
  local add_word = {}   -- new_lnum → [{col,end_col,hl_group}]
  local del_virts = {}  -- anchor new_lnum → list of virt_line chunk lists

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
          table.insert(
            del_virts[anchor_lnum],
            build_virt_chunks(dl.text, ts_hl_map[dl.old_lnum - 1], wd and wd.removed)
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
  self:_write(new_lines)
  self:_set_ft(file.path)

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
        table.insert(exts, { row = row - 1, col = 0, opts = {
          sign_text = "▾",
          sign_hl_group = "ReviewSignDelete",
          number_hl_group = "ReviewSignDelete",
        } })
      end
    end

    if add_set[lnum] then
      local sign_hl = change_set[lnum] and "ReviewSignChange" or "ReviewSignAdd"
      emit_line_exts(exts, row, new_lines[lnum], "ReviewDiffAdd", sign_hl, add_word[lnum])
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

  self:_show()
  self:_apply_folds()
end

function DiffView:destroy()
  word.clear_cache()
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    pcall(vim.api.nvim_buf_delete, self.bufnr, { force = true })
  end
end

return M
