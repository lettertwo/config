-- Review-owned statuscolumn: draws old/new line numbers for a combined-diff
-- pane and falls through to Snacks (plain single-number column) for every
-- other window, sbs included. Wired window-locally by Pane:bind.
--
-- A pane registers its bufnr here once, at buffer creation, and reads its
-- Review.Lnums back off the same table every redraw — no per-render
-- registration, since the buffer (and its registration) outlives any one
-- render.

local M = {}

---@type table<integer, Review.Pane>
local panes = {}

---@param bufnr integer
---@param pane Review.Pane
function M.register(bufnr, pane)
  panes[bufnr] = pane
end

---@param bufnr integer
function M.unregister(bufnr)
  panes[bufnr] = nil
end

---@param s string?
---@param width integer
---@return string
local function pad(s, width)
  s = s or ""
  return string.rep(" ", math.max(0, width - #s)) .. s
end

---@return snacks.statuscolumn?
local function snacks_statuscolumn()
  local ok, Snacks = pcall(require, "snacks")
  if not ok or not Snacks.did_setup then
    return nil
  end
  return Snacks
end

-- Mirrors nvim/lua/app/review/plugins/snacks.lua's statuscolumn.left/right
-- (the default app sets the same). Snacks.config.get folds in whichever
-- Snacks.setup() call actually ran first, so this is a fallback, not a
-- second source of truth.
local FALLBACK = { left = { "sign", "mark" }, right = { "fold", "git" } }

-- The higher-priority sign of `types` on this line, rendered through
-- Snacks' own icon formatting — mirrors the find(left_c)/find(right_c)
-- picking in snacks.statuscolumn._get(). Our panes always run with
-- signcolumn=yes and foldcolumn=1 (Pane:bind), so every sign/mark/fold type
-- is always wanted; there's no signcolumn=no/foldcolumn=0 case to gate on.
---@param Snacks table
---@param win integer
---@param buf integer
---@param lnum integer
---@param types string[]
---@return string
local function sign_slot(Snacks, win, buf, lnum, types)
  local sc = Snacks.statuscolumn
  local signs = sc.line_signs(win, buf, lnum, { sign = true, mark = true, fold = true, git = true })
  local by_type = {}
  for _, s in ipairs(signs) do
    by_type[s.type] = by_type[s.type] or s
  end
  for _, t in ipairs(types) do
    if by_type[t] then
      return sc.icon(by_type[t])
    end
  end
  return "  "
end

---@param entries {lnum: integer, hl: string}[]
---@param idx integer
---@param width integer
---@return string
local function virt_number(entries, idx, width)
  local e = entries[idx]
  if not e then
    return string.rep(" ", width)
  end
  return "%#" .. e.hl .. "#" .. pad(tostring(e.lnum), width) .. "%*"
end

-- Virtual line (del above/below its anchor, or a wrapped continuation): no
-- signs to draw, so each sign slot is blank padding in the same position as
-- on a real row (left slot, old, new, right slot). Padding both slots up
-- front shifts the old number two columns right, off its column.
---@param old_str string?  the rendered old number, nil for none
---@param width integer
---@return string
function M._virt_row(old_str, width)
  local blank = string.rep(" ", width)
  return "  " .. (old_str or blank) .. " " .. blank .. "   "
end

function M.get()
  local win = vim.g.statusline_winid
  local buf = vim.api.nvim_win_get_buf(win)
  local pane = panes[buf]
  local lnums = pane and pane.lnums

  local Snacks = snacks_statuscolumn()
  if not lnums then
    if Snacks then
      return Snacks.statuscolumn.get()
    end
    return "%l "
  end

  local width = lnums.width
  local virtnum = vim.v.virtnum
  local lnum = vim.v.lnum

  if virtnum ~= 0 then
    local old_str = nil
    if virtnum < 0 then
      local entries = lnums.virt_old[lnum - 1] or {}
      old_str = virt_number(entries, -virtnum, width)
    end
    return M._virt_row(old_str, width)
  end

  local left, right = "  ", "  "
  if Snacks then
    local config = Snacks.config.get("statuscolumn", FALLBACK)
    left = sign_slot(Snacks, win, buf, lnum, config.left)
    right = sign_slot(Snacks, win, buf, lnum, config.right)
  end

  local old_str, new_str
  if lnums.deleted then
    -- The buffer holds the old file: v:lnum already is the old number, and
    -- there's no new side to show.
    old_str = pad(tostring(lnum), width)
    new_str = string.rep(" ", width)
  else
    local old = lnums.old_of[lnum]
    old_str = old and pad(tostring(old), width) or string.rep(" ", width)
    new_str = pad(tostring(lnum), width)
  end

  local ret = left .. old_str .. " " .. new_str .. " " .. right
  return "%@v:lua.require'snacks.statuscolumn'.click_fold@" .. ret .. "%T"
end

return M
