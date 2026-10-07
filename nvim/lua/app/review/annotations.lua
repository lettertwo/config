-- Shows annotations in the diff panes and creates them from there. The
-- panes hold scratch text, not the file, so each row is mapped back to the
-- file line it shows (`DiffView:row_to_source`) and to the revision whose
-- content that side of the diff is: nil for the worktree, "index" for staged
-- content, otherwise the commit's full sha. A sha rather than a ref name,
-- since branch names move; a record keyed to a sha stays true to the
-- content it was written against, which also lets one annotation show up
-- as a commit's right side and the next commit's left side.

local M = {}

---@class Review.PaneSide
---@field path string
---@field rev string?

---@class Review.PaneIndex
---@field row_map table
---@field file Review.FileChange
---@field sides table<"LEFT"|"RIGHT", Review.PaneSide>
---@field rows table<"LEFT"|"RIGHT", table<integer, integer>>  file line -> 0-indexed buffer row

---@type table<integer, Review.PaneIndex>  pane buffer -> index of its last-seen render
local index_cache = {}

---@param buf integer
---@return Review.Docket?, Review.DiffView?, Review.Pane?
local function locate(buf)
  -- Never load the app just to answer "is this one of its buffers".
  local app = package.loaded["app.review"]
  local dk = app and app._active_docket()
  if not dk or dk._closed then
    return nil
  end
  for _, dv in ipairs({ dk.dv, dk.dv2 }) do
    for _, pane in ipairs({ dv.right, dv.left }) do
      if pane.bufnr == buf then
        return dk, dv, pane
      end
    end
  end
end

-- The sha a ref names: the changeset's own resolved shas where they apply,
-- `git rev-parse` for the rest (the HEAD side of an uncommitted sub-diff).
---@param dk Review.Docket
---@param file Review.FileChange
---@param ref string
---@return string?
local function sha_of(dk, file, ref)
  local owner = file.changeset_id ~= "" and file or dk:current_file()
  local cs = owner and dk.changesets[dk.cs_idx_by_id[owner.changeset_id]]
  if cs then
    if ref == cs.base_ref and cs.base_sha and cs.base_sha ~= "" then
      return cs.base_sha
    end
    if ref == cs.head_ref and cs.head_sha and cs.head_sha ~= "" then
      return cs.head_sha
    end
  end
  local r = vim.system({ "git", "rev-parse", "--verify", "--quiet", ref .. "^{commit}" }, { cwd = dk.cwd, text = true })
    :wait()
  if r.code == 0 then
    return vim.trim(r.stdout)
  end
end

---@param dk Review.Docket
---@param file Review.FileChange
---@param side "LEFT"|"RIGHT"
---@return Review.PaneSide?
local function side_of(dk, file, side)
  local ref = side == "LEFT" and (file.base_ref or "HEAD") or (file.head_ref or "WORKTREE")
  local path = side == "LEFT" and (file.old_path or file.path) or file.path
  if ref == "WORKTREE" then
    return { path = path, rev = nil }
  elseif ref == "INDEX" then
    return { path = path, rev = "index" }
  end
  local sha = sha_of(dk, file, ref)
  return sha and { path = path, rev = sha } or nil
end

-- What each side of `pane` currently shows, and the inverse of its row map.
-- Rebuilt only when the pane renders again (a render replaces `row_map`).
---@return Review.PaneIndex?
local function index_for(dk, dv, pane)
  local file = dv._rendered_file
  if not file then
    return nil
  end
  local cached = index_cache[pane.bufnr]
  if cached and cached.row_map == pane.row_map and cached.file == file then
    return cached
  end
  local built = { row_map = pane.row_map, file = file, sides = {}, rows = { LEFT = {}, RIGHT = {} } }
  for row, info in pairs(pane.row_map) do
    built.rows[info.side][info.lnum] = row
    if not built.sides[info.side] then
      built.sides[info.side] = side_of(dk, file, info.side) or false
    end
  end
  index_cache[pane.bufnr] = built
  return built
end

---@param buf integer
---@param lnum integer
---@param end_lnum integer
---@return Config.Annotations.Target?
local function resolve(buf, lnum, end_lnum)
  local dk, dv, pane = locate(buf)
  if not dk or not dv or not pane then
    return nil
  end
  local idx = index_for(dk, dv, pane)
  local function info_at(line)
    if pane:win_valid() then
      return dv:row_to_source(pane.win, line - 1)
    end
    return pane.row_map[line - 1]
  end

  -- Rows with no source (anything not a line of the file) can't carry an
  -- annotation, so a range pulls its ends in to the nearest ones that do.
  local first, last
  for line = lnum, end_lnum do
    if info_at(line) then
      first = line
      break
    end
  end
  for line = end_lnum, lnum, -1 do
    if info_at(line) then
      last = line
      break
    end
  end
  local notify = function(msg)
    vim.notify(msg, vim.log.levels.WARN, { title = "Annotations" })
  end
  if not first or not last or not idx then
    notify("No file lines to annotate here")
    return nil
  end
  local a, b = info_at(first), info_at(last)
  if a.side ~= b.side then
    notify("Selection spans both sides of the diff")
    return nil
  end
  local side = idx.sides[a.side]
  if not side then
    notify("Can't resolve the revision this side shows")
    return nil
  end

  local texts = {}
  for line = first, last do
    local info = info_at(line)
    if info then
      table.insert(texts, info.text)
    end
  end
  return {
    file = side.path,
    rev = side.rev,
    lnum = a.lnum,
    end_lnum = math.max(a.lnum, b.lnum),
    anchor_text = table.concat(texts, "\n"),
  }
end

---@param buf integer
---@param rec Config.Annotations.Record
---@return integer?, integer?
local function rows(buf, rec)
  local dk, dv, pane = locate(buf)
  if not dk or not dv or not pane then
    return nil
  end
  local idx = index_for(dk, dv, pane)
  if not idx then
    return nil
  end
  local rec_end = rec.end_lnum or rec.lnum
  for _, name in ipairs({ "RIGHT", "LEFT" }) do
    local side = idx.sides[name]
    if side and side.path == rec.file and side.rev == rec.rev then
      -- Lines outside the displayed hunks have no row; a range shows on
      -- whichever of its lines do.
      local first, last
      for l = rec.lnum, rec_end do
        local row = idx.rows[name][l]
        if row then
          first = first or row
          last = row
        end
      end
      if first then
        return first + 1, last + 1
      end
    end
  end
end

-- Register the diff panes with the annotations module. Idempotent: the
-- provider is keyed by name, so each review open replaces the last.
function M.register()
  require("config.annotations").register_provider({
    name = "review",
    match = function(buf)
      return locate(buf) ~= nil
    end,
    resolve = resolve,
    rows = rows,
  })
end

return M
