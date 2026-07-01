---@class Review.HunkSegment
---@field type "ctx"|"change"
---@field lines Review.HunkLine[]   -- ctx lines (type="ctx")
---@field dels Review.HunkLine[]    -- del lines (type="change")
---@field adds Review.HunkLine[]    -- add lines (type="change")

local M = {}

-- Partition hunk lines into alternating ctx and change segments.
-- Each change segment holds a contiguous del-run followed by an add-run.
---@param lines Review.HunkLine[]
---@return Review.HunkSegment[]
function M.segments(lines)
  local result = {}
  local i = 1
  while i <= #lines do
    local kind = lines[i].kind
    if kind == "ctx" then
      local seg = { type = "ctx", lines = {}, dels = {}, adds = {} }
      while i <= #lines and lines[i].kind == "ctx" do
        table.insert(seg.lines, lines[i])
        i = i + 1
      end
      table.insert(result, seg)
    else
      local seg = { type = "change", lines = {}, dels = {}, adds = {} }
      while i <= #lines and lines[i].kind == "del" do
        table.insert(seg.dels, lines[i])
        i = i + 1
      end
      while i <= #lines and lines[i].kind == "add" do
        table.insert(seg.adds, lines[i])
        i = i + 1
      end
      if #seg.dels > 0 or #seg.adds > 0 then
        table.insert(result, seg)
      end
    end
  end
  return result
end

return M
