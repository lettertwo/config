-- Persists annotation records to a sidecar JSON file per git worktree, at
-- <git-dir>/claude-annotations/annotations.json (`git rev-parse --git-dir` from
-- the current worktree, so linked worktrees get their own file). Never writes
-- into source files.
--
-- A second file next to it, resolutions.jsonl, is appended to by both sides:
-- claude/skills/annotations/SKILL.md writes a "changed"/"unchanged" row per
-- annotation it addresses, and `resolve()` below writes a "manual" row when
-- the user marks one resolved without sending it anywhere. Both only ever
-- append, so the two never conflict; nvim otherwise only rewrites this file
-- to drop rows, on `dismiss` or `unresolve`. Every load merges the latest row
-- per annotation id into that record's `resolution` field; the merge lives
-- only in memory, annotations.json itself never gains a `resolution` key.
--
-- Every mutation fires `User AnnotationsChanged` with `data = { ids }` so
-- anchor.lua and ui.lua can react without polling.

---@class Config.Annotations.Resolution
---@field status "changed"|"unchanged"|"manual" "manual" is written by nvim's own `resolve` action, the other two by the annotations skill
---@field note string
---@field ts integer
---@field turn_seq? string

---@class Config.Annotations.Record
---@field id string
---@field file string repo-relative path
---@field lnum integer
---@field end_lnum integer
---@field anchor_text string the annotated line(s), for drift detection
---@field body string
---@field created_at integer
---@field sent_at? integer
---@field batch? string
---@field resolution? Config.Annotations.Resolution merged in from resolutions.jsonl, not stored in annotations.json

local AnnotationStore = {}

---@type Config.Annotations.Record[]?
local cache = nil
local cache_path = nil

-- git-dir keyed by cwd, toplevel keyed by dirname. `false` is a cached miss
-- (not a git worktree), distinct from "not yet looked up". BufEnter and every
-- Store.load() would otherwise spawn `git rev-parse` synchronously per call.
local git_dir_cache = {}
local toplevel_cache = {}

local function reset_git_caches()
  git_dir_cache = {}
  toplevel_cache = {}
end

Config.on("DirChanged", reset_git_caches, "Drop memoized git-dir/toplevel lookups on cd")

-- vim.system throws (not just a nonzero exit) when `cwd` does not exist, so
-- every lookup here checks isdirectory first; a `term://`, `oil://`, or other
-- non-filesystem buffer name must never reach vim.system.
local function git_dir(cwd)
  if git_dir_cache[cwd] ~= nil then
    return git_dir_cache[cwd] or nil
  end
  if vim.fn.isdirectory(cwd) == 0 then
    git_dir_cache[cwd] = false
    return nil
  end
  local result = vim.system({ "git", "rev-parse", "--git-dir" }, { cwd = cwd, text = true }):wait()
  local dir = nil
  if result.code == 0 then
    local out = vim.trim(result.stdout or "")
    if out ~= "" then
      dir = out:sub(1, 1) == "/" and out or vim.fs.joinpath(cwd, out)
      dir = vim.fs.normalize(dir)
    end
  end
  git_dir_cache[cwd] = dir or false
  return dir
end

local function toplevel_for(dir)
  if toplevel_cache[dir] ~= nil then
    return toplevel_cache[dir] or nil
  end
  if vim.fn.isdirectory(dir) == 0 then
    toplevel_cache[dir] = false
    return nil
  end
  local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = dir, text = true }):wait()
  local top = nil
  if result.code == 0 then
    local out = vim.trim(result.stdout or "")
    if out ~= "" then
      top = vim.fs.normalize(out)
    end
  end
  toplevel_cache[dir] = top or false
  return top
end

---@return string?
local function resolve_path()
  local dir = git_dir(vim.uv.cwd())
  if not dir then
    return nil
  end
  return vim.fs.joinpath(dir, "claude-annotations", "annotations.json")
end

local function emit(ids)
  vim.api.nvim_exec_autocmds("User", { pattern = "AnnotationsChanged", data = { ids = ids } })
end

---@param annotations_path string
---@return string
local function resolutions_path(annotations_path)
  return vim.fs.joinpath(vim.fs.dirname(annotations_path), "resolutions.jsonl")
end

-- One resolution row per id, keeping the last one in the file for any id
-- that was resolved more than once.
---@param path string
---@return table<string, Config.Annotations.Resolution>
local function load_resolutions(path)
  local by_id = {}
  if vim.fn.filereadable(path) ~= 1 then
    return by_id
  end
  for _, line in ipairs(vim.fn.readfile(path)) do
    if line ~= "" then
      -- Claude appends this file directly; a row cut short by a killed
      -- write should not take down every other row.
      local ok, row = pcall(vim.json.decode, line)
      if ok and type(row) == "table" and row.id then
        by_id[row.id] = { status = row.status, note = row.note, ts = row.ts, turn_seq = row.turn_seq }
      end
    end
  end
  return by_id
end

-- Loads (or returns the cached) record list for the current worktree, with
-- each record's `resolution` merged in from resolutions.jsonl. The
-- cache-hit path (unchanged cwd, no file change since the last load) does
-- not spawn a process or re-read either file: `resolve_path` reads through
-- the memoized `git_dir` lookup, and watch.lua is what invalidates the
-- cache when either file changes on disk.
---@return Config.Annotations.Record[]
function AnnotationStore.load()
  local path = resolve_path()
  if not path then
    return {}
  end
  if cache ~= nil and cache_path == path then
    return cache
  end
  cache_path = path
  cache = {}
  if vim.fn.filereadable(path) == 1 then
    -- The sidecar file is hand-editable and can be truncated by a crash mid-write.
    local ok, decoded = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    end)
    if ok and type(decoded) == "table" then
      cache = decoded
    end
  end
  local resolutions = load_resolutions(resolutions_path(path))
  for _, rec in ipairs(cache) do
    rec.resolution = resolutions[rec.id]
  end
  return cache
end

function AnnotationStore.save()
  if cache == nil or cache_path == nil then
    return
  end
  local dir = vim.fs.dirname(cache_path)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  local ok, encoded = pcall(vim.json.encode, cache)
  if ok and encoded then
    vim.fn.writefile({ encoded }, cache_path)
  end
end

---@param rec Config.Annotations.Record
function AnnotationStore.add(rec)
  local records = AnnotationStore.load()
  table.insert(records, rec)
  AnnotationStore.save()
  emit({ rec.id })
end

---@param id string
---@param patch table
function AnnotationStore.update(id, patch)
  local records = AnnotationStore.load()
  for _, rec in ipairs(records) do
    if rec.id == id then
      for k, v in pairs(patch) do
        rec[k] = v
      end
      AnnotationStore.save()
      emit({ id })
      return
    end
  end
end

---@param id string
function AnnotationStore.remove(id)
  local records = AnnotationStore.load()
  for i, rec in ipairs(records) do
    if rec.id == id then
      table.remove(records, i)
      AnnotationStore.save()
      emit({ id })
      return
    end
  end
end

---@param file string repo-relative path
---@return Config.Annotations.Record[]
function AnnotationStore.for_file(file)
  local out = {}
  for _, rec in ipairs(AnnotationStore.load()) do
    if rec.file == file then
      table.insert(out, rec)
    end
  end
  return out
end

-- Records with no `sent_at`.
---@return Config.Annotations.Record[]
function AnnotationStore.pending()
  local out = {}
  for _, rec in ipairs(AnnotationStore.load()) do
    if rec.sent_at == nil then
      table.insert(out, rec)
    end
  end
  return out
end

---@param ids string[]
---@param batch string
function AnnotationStore.mark_sent(ids, batch)
  local records = AnnotationStore.load()
  local wanted = {}
  for _, id in ipairs(ids) do
    wanted[id] = true
  end
  local sent_at = os.time()
  for _, rec in ipairs(records) do
    if wanted[rec.id] then
      rec.sent_at = sent_at
      rec.batch = batch
    end
  end
  AnnotationStore.save()
  emit(ids)
end

-- Records with a merged-in resolution, i.e. Claude has addressed them.
---@return Config.Annotations.Record[]
function AnnotationStore.resolved()
  local out = {}
  for _, rec in ipairs(AnnotationStore.load()) do
    if rec.resolution ~= nil then
      table.insert(out, rec)
    end
  end
  return out
end

-- Rewrites resolutions.jsonl without any row for `id`.
---@param res_path string
---@param id string
local function drop_resolution_rows(res_path, id)
  if vim.fn.filereadable(res_path) ~= 1 then
    return
  end
  local kept = {}
  for _, line in ipairs(vim.fn.readfile(res_path)) do
    if line ~= "" then
      local ok, row = pcall(vim.json.decode, line)
      if ok and type(row) == "table" and row.id ~= id then
        table.insert(kept, line)
      end
    end
  end
  vim.fn.writefile(kept, res_path)
end

-- Removes the record and drops its rows from resolutions.jsonl (rewriting
-- the file without them), so a dismissed annotation doesn't reappear
-- resolved if its id is ever reused.
---@param id string
function AnnotationStore.dismiss(id)
  local records = AnnotationStore.load()
  local removed = false
  for i, rec in ipairs(records) do
    if rec.id == id then
      table.remove(records, i)
      removed = true
      break
    end
  end
  if not removed or cache_path == nil then
    return
  end
  AnnotationStore.save()
  drop_resolution_rows(resolutions_path(cache_path), id)
  emit({ id })
end

-- Marks a record resolved without sending it anywhere: appends a "manual"
-- row to resolutions.jsonl (the same file the skill appends to; both only
-- ever append, so there's nothing to conflict). Updates the in-memory record
-- immediately rather than waiting on the file watcher's debounce.
---@param id string
---@param note string? one line, may be empty
function AnnotationStore.resolve(id, note)
  local records = AnnotationStore.load()
  local rec
  for _, r in ipairs(records) do
    if r.id == id then
      rec = r
      break
    end
  end
  if not rec or cache_path == nil then
    return
  end

  local resolution = { status = "manual", note = note or "", ts = os.time() }
  local res_path = resolutions_path(cache_path)
  vim.fn.mkdir(vim.fs.dirname(res_path), "p")
  local lines = {}
  if vim.fn.filereadable(res_path) == 1 then
    lines = vim.fn.readfile(res_path)
  end
  table.insert(lines, vim.json.encode(vim.tbl_extend("force", { id = id }, resolution)))
  vim.fn.writefile(lines, res_path)

  rec.resolution = resolution
  emit({ id })
end

-- Reverses `resolve` (or a resolution the skill wrote): drops every
-- resolutions.jsonl row for `id` and clears `sent_at`/`batch`, so the
-- annotation is pending again and the next `send` picks it up.
---@param id string
function AnnotationStore.unresolve(id)
  local records = AnnotationStore.load()
  local rec
  for _, r in ipairs(records) do
    if r.id == id then
      rec = r
      break
    end
  end
  if not rec or cache_path == nil then
    return
  end

  drop_resolution_rows(resolutions_path(cache_path), id)
  rec.resolution = nil
  rec.sent_at = nil
  rec.batch = nil
  AnnotationStore.save()
  emit({ id })
end

-- The resolved git dir for `cwd` (absolute, worktree-aware), or nil if `cwd`
-- is not a real directory inside a git repo. Memoized; see `git_dir`.
---@param cwd string
---@return string?
function AnnotationStore.git_dir(cwd)
  return git_dir(cwd)
end

-- The git worktree toplevel containing `dir`, or nil if `dir` is not a real
-- directory inside a git worktree (a `term://`/`oil://`/etc. buffer's
-- directory, or one that was removed from disk). Memoized; see `toplevel_for`.
---@param dir string
---@return string?
function AnnotationStore.toplevel(dir)
  return toplevel_for(dir)
end

-- Resolves the given absolute path to a repo-relative path, or nil if it is
-- not a real filesystem path inside a git worktree. Used to build the `file`
-- field of a record. Never throws: callers pass arbitrary buffer names,
-- including `term://`, `oil://`, and other non-file scheme names.
---@param abs_path string
---@return string?
function AnnotationStore.relative_path(abs_path)
  if abs_path == "" or abs_path:find("://", 1, true) then
    return nil
  end
  local dir = vim.fs.dirname(abs_path)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    return nil
  end
  local toplevel = toplevel_for(dir)
  if not toplevel then
    return nil
  end
  local normalized = vim.fs.normalize(abs_path)
  if normalized:sub(1, #toplevel + 1) ~= toplevel .. "/" then
    return nil
  end
  return normalized:sub(#toplevel + 2)
end

-- Test-only: drops the in-memory cache so the next load() re-reads disk.
function AnnotationStore._reset_cache()
  cache = nil
  cache_path = nil
  reset_git_caches()
end

return AnnotationStore
