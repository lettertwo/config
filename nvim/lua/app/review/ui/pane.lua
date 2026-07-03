-- A single diff pane: one scratch buffer, the window it is currently bound
-- to, and that side's render products (hunk rows, row map, fold ranges).
-- The right pane shows the new file (the only pane inline); the left pane
-- shows the old file (side-by-side only). DiffView owns the pair and every
-- cross-pane concern (rendering, fold sync); everything single-pane lives
-- here.

local signs = require("app.review.ui.signs")

local M = {}

local fold_ns = vim.api.nvim_create_namespace("review_fold_gutter")

---@class Review.RowInfo
---@field lnum integer
---@field side "LEFT"|"RIGHT"
---@field text string

---@class Review.HunkRows
---@field s integer          -- 0-indexed first buffer row of the hunk
---@field e integer          -- 0-indexed last buffer row of the hunk
---@field first_diff integer -- first row that is an add or a del anchor
---@field last_diff integer

---@class Review.Pane
---@field bufnr integer
---@field win integer?  bound window; nil while unshown (left pane outside sbs)
---@field hunk_rows Review.HunkRows[]  ordered top-to-bottom; nav anchors
---@field row_map table<integer, Review.RowInfo>
---@field fold_ranges {s:integer,e:integer}[]
local Pane = {}
Pane.__index = Pane

---@return Review.Pane
function M.new()
  local self = setmetatable({}, Pane)
  self.win = nil
  self.hunk_rows = {}
  self.row_map = {}
  self.fold_ranges = {}

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "review-diff"
  self.bufnr = bufnr

  return self
end

function Pane:win_valid()
  return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

-- Bind a window: stores it and applies the diff window options. The buffer
-- swaps in via show(), so callers control when previous content disappears.
---@param win integer?
function Pane:bind(win)
  self.win = win
  if self:win_valid() then
    vim.wo[win].number = true
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "yes"
    vim.wo[win].foldcolumn = "1"
    vim.wo[win].conceallevel = 0
    vim.wo[win].wrap = false
  end
end

function Pane:unbind()
  self.win = nil
end

-- Show this pane's buffer in its bound window (no-op while unbound).
function Pane:show()
  if self:win_valid() then
    vim.api.nvim_win_set_buf(self.win, self.bufnr)
  end
end

-- Write lines to the buffer (clears its signs namespace).
function Pane:write(lines)
  vim.bo[self.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  vim.bo[self.bufnr].modifiable = false
  signs.clear(self.bufnr)
end

function Pane:set_ft(path)
  local ft = vim.filetype.match({ filename = path }) or ""
  if ft ~= "" and ft ~= vim.bo[self.bufnr].filetype then
    vim.bo[self.bufnr].filetype = ft
  end
  return ft
end

-- Drop the render products (buffer content stays) — placeholder/reset paths,
-- so stale hunk rows and row maps can't resolve against rewritten content.
function Pane:clear()
  self.hunk_rows = {}
  self.row_map = {}
  self.fold_ranges = {}
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

-- Foldtext for collapsed context regions (called via v:lua in the foldtext option).
function M._foldtext()
  local n = vim.v.foldend - vim.v.foldstart + 1
  return { { string.format("  ┄ %d lines ┄", n), "Folded" } }
end

-- Recompute this pane's fold ranges from its hunk rows and apply them to the
-- bound window. Window-local manual folds; the global foldmethod=expr from
-- the default app's folding plugin is per-window overridden here.
function Pane:refold()
  self.fold_ranges = compute_folds(self.hunk_rows, vim.api.nvim_buf_line_count(self.bufnr))
  if not self:win_valid() then
    return
  end
  local win, bufnr = self.win, self.bufnr
  vim.api.nvim_buf_clear_namespace(bufnr, fold_ns, 0, -1)
  vim.api.nvim_win_call(win, function()
    vim.wo[win][0].foldmethod = "manual"
    vim.wo[win][0].foldenable = true
    vim.wo[win][0].foldlevel = 0
    vim.wo[win][0].foldtext = "v:lua.require'app.review.ui.pane'._foldtext()"
    vim.cmd("normal! zE")
    for _, r in ipairs(self.fold_ranges) do
      if r.s <= r.e then
        vim.api.nvim_buf_set_extmark(bufnr, fold_ns, r.s, 0, {
          number_hl_group = "Folded",
        })
        vim.cmd(string.format("%d,%dfold", r.s + 1, r.e + 1))
      end
    end
  end)
end

function Pane:destroy()
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    pcall(vim.api.nvim_buf_delete, self.bufnr, { force = true })
  end
end

return M
