---@class RecallUtil
local M = {}

---@class RecallMark
---@field letter string Mark letter (A-Z)
---@field file string File path associated with the mark
---@field pos [integer, integer] Position in the file as [lnum, col]

---@class IterMarks: Iter
---@field each fun(self: IterMarks, fn: fun(mark: RecallMark))
---@field filter fun(self: IterMarks, fn: fun(mark: RecallMark): boolean): IterMarks
---@field find fun(self: IterMarks, fn: fun(mark: RecallMark): boolean): RecallMark|nil
---@field last fun(self: IterMarks): RecallMark|nil
---@field map fun(self: IterMarks, fn: fun(mark: RecallMark): any): Iter
---@field next fun(self: IterMarks): RecallMark|nil
---@field rev fun(self: IterMarks): IterMarks
---@field totable fun(self: IterMarks): RecallMark[]

-- Normalize a file path or buffer name
---@param bufnr_or_filepath integer|string Buffer number or file path
function M.normalize_filepath(bufnr_or_filepath)
  if type(bufnr_or_filepath) == "number" then
    return vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr_or_filepath))
  else
    ---@cast bufnr_or_filepath -integer
    return vim.fs.normalize(bufnr_or_filepath)
  end
end

-- Get the current cursor position in the given buffer.
-- If the buffer is not open in a window, returns start of buffer.
---@param bufnr integer Buffer number
---@return [integer, integer] pos `{lnum, col}`
local function get_current_pos(bufnr)
  local pos = { 1, 0 } -- Default to start of file
  -- Get current cursor position if buffer is open in a window
  local wins = vim.fn.win_findbuf(bufnr)
  if #wins > 0 then
    local win = wins[1]
    pos = vim.api.nvim_win_get_cursor(win)
  end
  return pos
end

---@param force_recall_update boolean? Whether to force a recall update
local function dispatch_update(force_recall_update)
  if force_recall_update then
    require("recall.marking").on_mark_update()
  end
  vim.api.nvim_exec_autocmds("User", { pattern = "RecallUpdate" })
end

-- If `bufnr_or_filepath` is given, adds a mark to the current position in the buffer,
-- if open, or to the start of the file, if not open.
-- Otherwise, adds a mark as per recall's default behavior.
--
-- If `mark_letter` (A-Z) is given as the first argument, sets that specific mark letter
-- instead of the next available one. A `bufnr_or_filepath` and optional `pos` must also be provided
-- in this case. If the `pos` is not provided, defaults to the current position if open in a window,
-- or start of the file.
--
-- Note that in the second form, marks will not be compacted automatically, so you may end up
-- with non-contiguous marks. You can call `compact_marks()` afterward to fix this,
-- but note that the new mark letter may change as a result.
---@param bufnr_or_filepath? integer|string Buffer number or file path to mark
---@overload fun(mark_letter: string, bufnr_or_filepath: integer|string, pos?: [integer, integer])
function M.mark(bufnr_or_filepath_or_mark_letter, bufnr_or_filepath, pos)
  -- If first argument is a letter A-Z, set that specific mark
  if type(bufnr_or_filepath_or_mark_letter) == "string" and bufnr_or_filepath_or_mark_letter:match("^[A-Z]$") then
    local mark_letter = bufnr_or_filepath_or_mark_letter
    assert(bufnr_or_filepath ~= nil, "Buffer number or file path must be provided when setting specific mark letter")
    local normalized = M.normalize_filepath(bufnr_or_filepath)
    local bufnr = vim.fn.bufadd(normalized)
    pos = pos or get_current_pos(bufnr)
    -- Set mark at determined position
    local ok = pcall(vim.fn.setpos, "'" .. mark_letter, { bufnr, pos[1], pos[2], 0 })
    if ok then
      dispatch_update(true)
    else
      vim.notify("Failed to set mark " .. mark_letter .. " on " .. normalized, vim.log.levels.ERROR)
      return
    end
  elseif bufnr_or_filepath_or_mark_letter ~= nil then
    bufnr_or_filepath = bufnr_or_filepath_or_mark_letter
    local next_mark_letter = M.get_next_available_mark()

    if next_mark_letter == nil then
      vim.notify("No available marks (A-Z all in use)", vim.log.levels.WARN)
      return
    end

    local normalized = M.normalize_filepath(bufnr_or_filepath)
    local bufnr = vim.fn.bufadd(normalized)
    pos = get_current_pos(bufnr)

    -- Set mark at determined position
    local ok = pcall(vim.fn.setpos, "'" .. next_mark_letter, { bufnr, pos[1], pos[2], 0 })
    if ok then
      M.compact_marks()
      dispatch_update(true)
    else
      vim.notify("Failed to set mark " .. next_mark_letter .. " on " .. normalized, vim.log.levels.ERROR)
      return
    end
  else
    require("recall").mark()
    M.compact_marks()
    dispatch_update()
  end
end

-- If `bufnr_or_filepath_mark` is a letter A-Z, unmark that specific mark.
-- If `bufnr_or_filepath_mark` is a number or filepath, unmark all marks in that buffer or file.
-- Otherwise, unmark the current mark as per recall's default behavior.
---@param bufnr_or_filepath_or_mark? integer|string Buffer number or file path to unmark
function M.unmark(bufnr_or_filepath_or_mark)
  if bufnr_or_filepath_or_mark ~= nil then
    if type(bufnr_or_filepath_or_mark) == "string" and bufnr_or_filepath_or_mark:match("^[A-Z]$") then
      -- Unmark specific mark letter
      pcall(vim.api.nvim_del_mark, bufnr_or_filepath_or_mark)
      M.compact_marks()
      dispatch_update(true)
    else
      M.iter_marks(bufnr_or_filepath_or_mark):each(function(mark)
        pcall(vim.api.nvim_del_mark, mark.letter)
      end)
      M.compact_marks()
      dispatch_update(true)
    end
  else
    require("recall").unmark()
    M.compact_marks()
    dispatch_update()
  end
end

-- If `bufnr_or_filepath` is given, remove all existing marks in that file
-- if any exist, or add a new mark if none exist.
-- Otherwise, toggles the current mark as per recall's default behavior.
---@param bufnr_or_filepath? integer|string Buffer number or file path to toggle mark on
function M.toggle(bufnr_or_filepath)
  if bufnr_or_filepath ~= nil then
    if M.has_marks(bufnr_or_filepath) then
      M.unmark(bufnr_or_filepath)
    else
      M.mark(bufnr_or_filepath)
    end
  else
    require("recall").toggle()
    M.compact_marks()
    dispatch_update()
  end
end

-- Check if there are any marks in the given buffer or file.
---@param bufnr_or_filepath? integer|string Buffer number or file path to check for marks
function M.has_marks(bufnr_or_filepath)
  return M.iter_marks(bufnr_or_filepath):next() ~= nil
end

---@param to_remark RecallMark[] List of marks to remark with new letters
function M.remark(to_remark)
  -- first pass, unmark all marks that need to be re-marked
  for _, mark in ipairs(to_remark) do
    local ok = pcall(vim.api.nvim_del_mark, mark.letter)
    if not ok then
      vim.notify("Failed to unmark " .. mark.letter .. " on " .. mark.file, vim.log.levels.ERROR)
    end
  end

  -- manually compact to guarantee contiguous ordering
  M.compact_marks()

  -- second pass, re-mark in new order
  for _, mark in ipairs(to_remark) do
    -- Set next available mark letter in given file at given position
    local letter = assert(M.get_next_available_mark(), "no available marks")
    local bufnr = vim.fn.bufadd(M.normalize_filepath(mark.file))
    local ok = pcall(vim.fn.setpos, "'" .. letter, { bufnr, mark.pos[1], mark.pos[2], 0 })
    if not ok then
      vim.notify("Failed to set mark " .. letter .. " on " .. mark.file, vim.log.levels.ERROR)
    end
  end

  dispatch_update(true)
end

---@return boolean True if any marks were compacted, false otherwise
function M.compact_marks()
  local to_remark = M.iter_marks():enumerate():fold({}, function(acc, i, mark)
    -- If any previous marks need to be re-lettered, so does this one.
    -- Otherwise, check if this mark has the exjpected A-Z letter for its position.
    if #acc or mark.letter ~= string.char(64 + i) then -- 'A' is 65 in ASCII
      table.insert(acc, mark)
    end
    return acc
  end)

  if #to_remark == 0 then
    return false
  end

  -- first pass: unmark all marks that need to be re-lettered
  for _, mark in ipairs(to_remark) do
    pcall(vim.api.nvim_del_mark, mark.letter)
  end

  -- second pass: re-mark them with the next available letters
  for _, mark in ipairs(to_remark) do
    local next_mark_letter = M.get_next_available_mark()
    if next_mark_letter == nil then
      vim.notify("No available marks (A-Z all in use)", vim.log.levels.WARN)
      return true
    end
    pcall(vim.fn.setpos, "'" .. next_mark_letter, { vim.fn.bufadd(mark.file), mark.pos[1], mark.pos[2], 0 })
  end
  return true
end

-- Get the next available mark letter (A-Z) that is not currently used
---@return string? letter -- The next available mark letter or nil if none available
function M.get_next_available_mark()
  local last_used_mark = M.iter_marks():last()
  local last_letter = last_used_mark and last_used_mark.letter or nil
  if last_letter then
    if last_letter >= "A" and last_letter < "Z" then
      return string.char(string.byte(last_letter) + 1)
    end
  else
    return "A"
  end
end

function M.goto_next()
  require("recall").goto_next()
  M.set_last_jumped_mark()
end

function M.goto_prev()
  require("recall").goto_prev()
  M.set_last_jumped_mark()
end

function M.clear()
  require("recall").clear()
  dispatch_update()
end

---@param bufnr_or_filepath? integer|string Buffer number or file path to filter marks by
---@return IterMarks
function M.iter_marks(bufnr_or_filepath)
  -- Use pcall to safely get marks, especially in fast event contexts
  local ok, mark_info = pcall(vim.fn.getmarklist)
  if not ok then
    return vim.iter()
  end

  local normalized_filepath = bufnr_or_filepath and M.normalize_filepath(bufnr_or_filepath) or nil

  table.sort(mark_info, function(a, b)
    return a.mark < b.mark
  end)

  return vim.iter(mark_info):map(function(mark)
    local normalized_mark_filepath = mark.file and vim.fs.normalize(mark.file) or nil

    if normalized_filepath and normalized_filepath ~= normalized_mark_filepath then
      return nil
    end

    local mark_letter = mark.mark:match("^'([A-Z])$")
    if mark_letter and normalized_mark_filepath and mark.pos and mark.pos[2] and mark.pos[3] then
      return {
        letter = mark_letter,
        file = normalized_mark_filepath,
        pos = { mark.pos[2], mark.pos[3] },
      }
    end
  end) --[[@as IterMarks]]
end

function M.iter_marked_files()
  local seen = {}
  return M.iter_marks():map(function(mark)
    if not seen[mark.file] then
      seen[mark.file] = true
      return mark.file
    end
  end)
end

-- Get a specific mark by its letter
---@param mark_letter string The mark letter to get
---@return RecallMark? mark The mark info table or nil if not found
function M.get_mark(mark_letter)
  return M.iter_marks():find(function(m)
    return m.letter == mark_letter
  end)
end

---Get all marks with their file paths and positions
---@return table[] marks Array of mark info tables with letter, file, and pos fields
function M.get_all_marks()
  return M.iter_marks():totable()
end

---Get mark letter for a file path
---@param filepath string The file path to check
---@return string? letter The mark letter or nil if not marked
function M.get_file_mark(filepath)
  return M.iter_marks(filepath):next()
end

---Get the mark at current cursor position (approximate - within 5 lines)
---@param bufnr? integer Buffer number (defaults to current buffer)
---@return string? letter The mark letter at cursor position
function M.get_mark_at_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" then
    return nil
  end

  local normalized_bufname = vim.fs.normalize(bufname)
  local marks = M.get_all_marks()

  -- Find mark closest to cursor position in this buffer
  local closest_mark = nil
  local closest_distance = math.huge

  for _, mark in ipairs(marks) do
    if mark.file == normalized_bufname and mark.pos and mark.pos[1] then
      local distance = math.abs(mark.pos[1] - cursor_line)
      -- Only consider marks within 5 lines
      if distance <= 5 and distance < closest_distance then
        closest_distance = distance
        closest_mark = mark.letter
      end
    end
  end

  return closest_mark
end

---Set the last jumped-to mark (called after goto_next/goto_prev)
---@param bufnr? integer Buffer number
function M.set_last_jumped_mark(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local mark_letter = M.get_mark_at_cursor(bufnr)
  if mark_letter then
    vim.b[bufnr].recall_last_jumped_mark = mark_letter
  end
end

---Get the last jumped-to mark for a buffer
---@param bufnr? integer Buffer number (defaults to current buffer)
---@return string? letter The last jumped-to mark letter
function M.get_last_jumped_mark(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.b[bufnr].recall_last_jumped_mark
end

return M
