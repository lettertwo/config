-- Word-level (intra-line) diff highlights via codediff's core diff engine.
-- Returns structured highlight ranges that can be applied to any buffer.
-- Falls back gracefully (returns nil) when codediff is unavailable.

local M = {}

local _cache = {}

-- codediff.core.diff is an internal module whose load can run a blocking
-- network auto-installer and error() on failure — and Lua does not cache
-- failed requires. Resolve it once and remember the failure so a broken
-- install degrades to "no word diff" instead of retrying per cache miss.
local _mod = nil       -- resolved module, false = resolution failed
local function diff_mod()
  if _mod == nil then
    local ok, mod = pcall(require, "codediff.core.diff")
    _mod = ok and mod or false
  end
  return _mod or nil
end

-- Compute word-level diff highlights for a paired (add, del) line.
-- add_text = added line content (no + prefix), del_text = removed line content
-- (no - prefix). Returns { added: [{col, end_col, hl_group}], removed: [...] }
-- or nil. Cols are 0-based, end-exclusive (extmark-ready).
---@param add_text string
---@param del_text string
---@return {added: table[], removed: table[]}?
function M.compute(add_text, del_text)
  if add_text == del_text then
    return nil
  end

  local key = add_text .. "\0" .. del_text
  if _cache[key] ~= nil then
    return _cache[key] or nil
  end

  local mod = diff_mod()
  if not mod then
    _cache[key] = false
    return nil
  end

  -- del is the "original" side, add the "modified" side.
  local ok, result = pcall(mod.compute_diff, { del_text }, { add_text }, { extend_to_subwords = true })
  if not ok or not result or not result.changes then
    _cache[key] = false
    return nil
  end

  local added, removed = {}, {}
  for _, change in ipairs(result.changes) do
    for _, inner in ipairs(change.inner_changes or {}) do
      -- CharRanges are 1-based with end-exclusive end_col; single-line inputs
      -- keep everything on line 1. Convert to 0-based end-exclusive cols.
      local o = inner.original
      if o and o.end_col > o.start_col then
        table.insert(removed, { col = o.start_col - 1, end_col = o.end_col - 1, hl_group = "ReviewDiffDeleteWord" })
      end
      local m = inner.modified
      if m and m.end_col > m.start_col then
        table.insert(added, { col = m.start_col - 1, end_col = m.end_col - 1, hl_group = "ReviewDiffAddWord" })
      end
    end
  end

  local out = { added = added, removed = removed }
  _cache[key] = out
  return out
end

function M.clear_cache()
  _cache = {}
end

return M
