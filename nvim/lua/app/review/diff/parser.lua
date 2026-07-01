---@class Review.HunkLine
---@field kind "ctx"|"add"|"del"
---@field text string
---@field old_lnum? integer
---@field new_lnum? integer

---@class Review.Hunk
---@field old_start integer
---@field old_count integer
---@field new_start integer
---@field new_count integer
---@field lines Review.HunkLine[]
---@field raw string[]  raw diff lines (header + body) for patch reconstruction

---@class Review.FileChange
---@field path string
---@field old_path? string
---@field status "M"|"A"|"D"|"R"|"C"|"B"|"U"
---@field hunks Review.Hunk[]
---@field changeset_id string
---@field base_ref string
---@field head_ref string
---@field staged? boolean           -- file only in the staged diff (fully staged)
---@field staged_hunks? Review.Hunk[]  -- staged hunks when both staged and unstaged exist
---@field unstaged? Review.FileChange      -- worktree↔index sub-diff (base_ref="INDEX", head_ref="WORKTREE")
---@field staged_change? Review.FileChange -- index↔HEAD sub-diff (base_ref="HEAD", head_ref="INDEX")

local M = {}

-- Parse a unified diff string into a list of FileChange objects.
---@param raw string
---@return Review.FileChange[]
function M.parse(raw)
  local files = {}
  local current_file = nil
  local current_hunk = nil
  local old_lnum = 0
  local new_lnum = 0

  local function flush_hunk()
    if current_hunk and current_file then
      table.insert(current_file.hunks, current_hunk)
      current_hunk = nil
    end
  end

  local function flush_file()
    flush_hunk()
    if current_file then
      table.insert(files, current_file)
      current_file = nil
    end
  end

  for line in (raw .. "\n"):gmatch("([^\n]*)\n") do
    -- New file diff header
    local a, b = line:match("^diff %-%-git a/(.-) b/(.-)$")
    if a then
      flush_file()
      current_file = {
        path = b,
        old_path = a ~= b and a or nil,
        status = "M",
        hunks = {},
        changeset_id = "",
      }
      goto continue
    end

    if not current_file then
      goto continue
    end

    -- Rename / copy markers
    if line:match("^rename from (.+)$") then
      current_file.old_path = line:match("^rename from (.+)$")
      current_file.status = "R"
      goto continue
    end
    if line:match("^rename to (.+)$") then
      current_file.path = line:match("^rename to (.+)$")
      goto continue
    end
    if line:match("^copy from") then
      current_file.status = "C"
      goto continue
    end

    -- Binary
    if line:match("^Binary files") then
      current_file.status = "B"
      goto continue
    end

    -- Mode lines
    if line:match("^new file mode") then
      current_file.status = "A"
      goto continue
    end
    if line:match("^deleted file mode") then
      current_file.status = "D"
      goto continue
    end

    -- Skip file-level header lines. Guard on current_hunk==nil so that deleted
    -- lines like "--- some comment" inside a hunk are not swallowed as headers.
    if not current_hunk and (
      line:match("^index ") or line:match("^%-%-%- ") or line:match("^%+%+%+ ") or line:match("^similarity index")
    ) then
      goto continue
    end

    -- Hunk header: @@ -old_start[,old_count] +new_start[,new_count] @@
    do
      local os, oc, ns, nc = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
      if os then
        flush_hunk()
        old_lnum = tonumber(os) or 0
        new_lnum = tonumber(ns) or 0
        current_hunk = {
          old_start = tonumber(os),
          old_count = oc ~= "" and tonumber(oc) or 1,
          new_start = tonumber(ns),
          new_count = nc ~= "" and tonumber(nc) or 1,
          lines = {},
          raw = { line },  -- accumulate raw bytes for patch reconstruction
        }
        goto continue
      end
    end

    if not current_hunk then
      goto continue
    end

    -- Diff lines
    if line == "\\ No newline at end of file" then
      table.insert(current_hunk.raw, line)
      goto continue
    end

    local first = line:sub(1, 1)
    local text = line:sub(2)
    local kind

    if first == "+" then
      kind = "add"
    elseif first == "-" then
      kind = "del"
    elseif first == " " then
      kind = "ctx"
    else
      goto continue
    end

    table.insert(current_hunk.raw, line)
    local entry = { kind = kind, text = text }
    if kind == "del" or kind == "ctx" then
      entry.old_lnum = old_lnum
      old_lnum = old_lnum + 1
    end
    if kind == "add" or kind == "ctx" then
      entry.new_lnum = new_lnum
      new_lnum = new_lnum + 1
    end
    table.insert(current_hunk.lines, entry)

    ::continue::
  end

  flush_file()
  return files
end

-- Reconstruct a minimal unified-diff patch for a single hunk, suitable for
-- `git apply [--cached] [--reverse]`.  Uses the raw bytes captured during
-- parsing so no line-content reconstruction is needed.
---@param file Review.FileChange
---@param hunk Review.Hunk
---@return string
function M.hunk_to_patch(file, hunk)
  local a_path = file.old_path or file.path
  local b_path = file.path
  local lines = {
    "diff --git a/" .. a_path .. " b/" .. b_path,
    "--- a/" .. a_path,
    "+++ b/" .. b_path,
  }
  for _, raw_line in ipairs(hunk.raw or {}) do
    table.insert(lines, raw_line)
  end
  -- git apply requires a trailing newline
  return table.concat(lines, "\n") .. "\n"
end

-- Build a trimmed unified-diff patch for a line-precise selection within a hunk.
-- keep_add(entry) → boolean: include this add line; dropped adds are omitted entirely.
-- keep_del(entry) → boolean: keep this del as a deletion; dropped dels become context.
-- ctx lines are always included.  Raw bytes are used for kept lines; converted dels
-- are reconstructed with a " " prefix.  "\ No newline at end of file" markers are
-- walked from hunk.raw in parallel and emitted with their associated line.
---@param file Review.FileChange
---@param hunk Review.Hunk
---@param keep_add fun(entry: Review.HunkLine): boolean
---@param keep_del fun(entry: Review.HunkLine): boolean
---@return string  unified-diff patch
function M.hunk_to_patch_lines(file, hunk, keep_add, keep_del)
  local a_path = file.old_path or file.path
  local b_path = file.path

  local out = {}
  local old_count = 0
  local new_count = 0

  -- Walk raw lines (skipping the @@ header at index 1) in parallel with hunk.lines,
  -- grouping each entry with any following "\ No newline" markers.
  local raw = hunk.raw or {}
  local ri = 2  -- raw[1] is the @@ header

  for _, entry in ipairs(hunk.lines) do
    local raw_line = raw[ri]
    ri = ri + 1
    local markers = {}
    while raw[ri] and raw[ri]:sub(1, 1) == "\\" do
      table.insert(markers, raw[ri])
      ri = ri + 1
    end

    if entry.kind == "ctx" then
      table.insert(out, raw_line or (" " .. entry.text))
      for _, m in ipairs(markers) do table.insert(out, m) end
      old_count = old_count + 1
      new_count = new_count + 1
    elseif entry.kind == "add" then
      if keep_add(entry) then
        table.insert(out, raw_line or ("+" .. entry.text))
        for _, m in ipairs(markers) do table.insert(out, m) end
        new_count = new_count + 1
      end
      -- dropped add: omit entirely (markers too)
    elseif entry.kind == "del" then
      if keep_del(entry) then
        table.insert(out, raw_line or ("-" .. entry.text))
        for _, m in ipairs(markers) do table.insert(out, m) end
        old_count = old_count + 1
      else
        -- Convert dropped del to context
        table.insert(out, " " .. entry.text)
        for _, m in ipairs(markers) do table.insert(out, m) end
        old_count = old_count + 1
        new_count = new_count + 1
      end
    end
  end

  local header = ("@@ -%d,%d +%d,%d @@"):format(hunk.old_start, old_count, hunk.new_start, new_count)
  local result = {
    "diff --git a/" .. a_path .. " b/" .. b_path,
    "--- a/" .. a_path,
    "+++ b/" .. b_path,
    header,
  }
  for _, l in ipairs(out) do
    table.insert(result, l)
  end
  return table.concat(result, "\n") .. "\n"
end

return M
