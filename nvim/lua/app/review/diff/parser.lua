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
-- keep_add(entry) → boolean: include this add line. keep_del(entry) → boolean:
-- keep this del as a deletion. ctx lines are always included.
--
-- `base` names the side the patch will be matched against, which decides what
-- dropped lines become:
--   "old" (default; forward `git apply` onto a base equal to the OLD side —
--   staging into an index that lacks the change): dropped adds are omitted
--   (absent from the base), dropped dels become context (still in the base).
--   "new" (`git apply --reverse` onto a base equal to the NEW side — unstaging
--   an index / discarding a worktree that CONTAINS the change): the mirror
--   image — dropped adds become context (present in the base and staying),
--   dropped dels are omitted (already absent from the base).
-- Using "old" rules for a reverse apply makes git match dropped lines against
-- a side they don't exist on — context mismatch on any partial selection.
--
-- Raw bytes are used for kept lines; converted lines are reconstructed with a
-- " " prefix.  "\ No newline at end of file" markers are walked from hunk.raw
-- in parallel and travel with their associated line (omitted lines drop theirs).
---@param file Review.FileChange
---@param hunk Review.Hunk
---@param keep_add fun(entry: Review.HunkLine): boolean
---@param keep_del fun(entry: Review.HunkLine): boolean
---@param base? "old"|"new"
---@return string  unified-diff patch
function M.hunk_to_patch_lines(file, hunk, keep_add, keep_del, base)
  local a_path = file.old_path or file.path
  local b_path = file.path
  local drop_to_ctx_kind = (base == "new") and "add" or "del"

  local out = {}
  local old_count = 0
  local new_count = 0
  -- A dropped del converted to context can carry a "\ No newline at end of
  -- file" marker (the old side's EOF). That is only valid as the patch's
  -- final body line; when a kept add follows, git silently CONCATENATES the
  -- add onto the no-newline line (verified against git 2.x — no rejection,
  -- corrupted blob). Track the conversion so it can be spliced into git's
  -- canonical del+re-add form when anything follows it.
  local eof_ctx -- {idx: position of the converted text in out, text, n_markers}

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
      elseif drop_to_ctx_kind == "add" then
        -- base="new": the unkept add exists in the base and stays — context.
        table.insert(out, " " .. entry.text)
        for _, m in ipairs(markers) do table.insert(out, m) end
        old_count = old_count + 1
        new_count = new_count + 1
      end
      -- base="old": dropped add omitted entirely (markers too)
    elseif entry.kind == "del" then
      if keep_del(entry) then
        table.insert(out, raw_line or ("-" .. entry.text))
        for _, m in ipairs(markers) do table.insert(out, m) end
        old_count = old_count + 1
      elseif drop_to_ctx_kind == "del" then
        -- base="old": the unkept del is still present in the base — context.
        table.insert(out, " " .. entry.text)
        if #markers > 0 then
          eof_ctx = { idx = #out, text = entry.text, n_markers = #markers }
        end
        for _, m in ipairs(markers) do table.insert(out, m) end
        old_count = old_count + 1
        new_count = new_count + 1
      end
      -- base="new": dropped del omitted entirely (markers too). A converted
      -- add can also carry a marker (new-side EOF), but git orders dels
      -- before adds within a block, so nothing kept can follow it — the
      -- eof_ctx splice is only needed on the del side.
    end
  end

  -- Splice a mid-body no-newline context line into del+re-add: the old side
  -- ends without a newline at this line, and the re-added copy (with a
  -- newline, since kept lines follow) preserves it on the new side. Counts
  -- are unchanged: ctx counted 1 old + 1 new, and del+add count the same.
  if eof_ctx and eof_ctx.idx + eof_ctx.n_markers < #out then
    out[eof_ctx.idx] = "-" .. eof_ctx.text
    table.insert(out, eof_ctx.idx + eof_ctx.n_markers + 1, "+" .. eof_ctx.text)
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

-- Predicates for hunk_to_patch_lines selecting the hunk lines whose source
-- lines fall inside a visual selection [lo, hi] (1-based lnums in `side`'s
-- coordinate space). Pure — walks hunk.lines only.
--
-- RIGHT (new-side rows; the primary pane in both layouts): adds match their
-- new_lnum exactly. Dels aren't buffer rows there — the renderer draws them
-- as virt_lines above an anchor — so a del run is attributed to the line the
-- user perceives it at, mirroring the renderer's anchor rule:
--   • run followed by adds (a change segment): the first add's line, so
--     selecting the replacement stages its deletion with it;
--   • pure-del run: the line ABOVE the virt block (the ]h/[h nav target),
--     i.e. the previous new-side line, clamped into the hunk when the run
--     leads it.
-- LEFT (sbs old pane): dels match their old_lnum exactly; adds never match —
-- the left pane stages deletions precisely, adds are selected on the right.
---@param hunk Review.Hunk
---@param side "LEFT"|"RIGHT"
---@param lo integer
---@param hi integer
---@return fun(entry: Review.HunkLine): boolean keep_add
---@return fun(entry: Review.HunkLine): boolean keep_del
---@return integer kept  number of add/del lines selected
function M.line_predicates(hunk, side, lo, hi)
  local keep = {} ---@type table<Review.HunkLine, boolean>
  local kept = 0

  if side == "LEFT" then
    for _, entry in ipairs(hunk.lines) do
      if entry.kind == "del" and entry.old_lnum >= lo and entry.old_lnum <= hi then
        keep[entry] = true
        kept = kept + 1
      end
    end
  else
    local lines = hunk.lines
    local i = 1
    while i <= #lines do
      local entry = lines[i]
      if entry.kind == "add" then
        if entry.new_lnum >= lo and entry.new_lnum <= hi then
          keep[entry] = true
          kept = kept + 1
        end
        i = i + 1
      elseif entry.kind == "del" then
        -- Maximal del run [i, j]; all its dels share one perceived line.
        local j = i
        while j < #lines and lines[j + 1].kind == "del" do
          j = j + 1
        end
        local nxt = lines[j + 1]
        local prev -- last new-side line before the run
        for k = i - 1, 1, -1 do
          if lines[k].new_lnum then
            prev = lines[k]
            break
          end
        end
        local eff
        if nxt and nxt.kind == "add" then
          eff = nxt.new_lnum
        elseif prev then
          eff = prev.new_lnum
        elseif nxt then
          -- Run leads the hunk: clamp the "line above" into the hunk.
          eff = math.max(hunk.new_start, nxt.new_lnum - 1)
        else
          -- Hunk is nothing but dels (new_count == 0): unified convention
          -- puts new_start on the line before the change, where the renderer
          -- anchors the virt block.
          eff = math.max(1, hunk.new_start)
        end
        if eff >= lo and eff <= hi then
          for k = i, j do
            keep[lines[k]] = true
            kept = kept + 1
          end
        end
        i = j + 1
      else
        i = i + 1
      end
    end
  end

  -- One identity set serves both predicates: kinds are disjoint.
  local function keep_entry(entry)
    return keep[entry] == true
  end
  return keep_entry, keep_entry, kept
end

return M
