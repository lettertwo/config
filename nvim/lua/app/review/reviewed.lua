-- Reviewed marks: which files of a changeset the user has read.
--
-- A mark is keyed by the file's path plus its old and new blob ids, so it
-- follows the diff's content rather than a changeset id ("uncommitted" is a
-- constant, and a stack node's id says nothing about what changed). When the
-- file's diff changes, the key changes and the file reads as unreviewed
-- again. Marks live in the git common dir so every worktree of a repo shares
-- them, and each toggle re-reads the file first so two nvims only lose
-- whichever write lands second.
--
-- Fires `User ReviewReviewedChanged` after every write.

local M = {}

local cwd_override = nil
local cache = { path = nil, stamp = nil, set = {} }

-- Point the store at a checkout. Without a call it follows the git root of
-- the current directory.
---@param cwd string?
function M.use(cwd)
  cwd_override = cwd
  cache = { path = nil, stamp = nil, set = {} }
end

---@return string?
local function store_path()
  local cwd = cwd_override or Config.root("git") or vim.fn.getcwd()
  local dir = require("app.review.diff.git").common_dir_sync(cwd)
  return dir and (dir .. "/review/reviewed.json") or nil
end

---@param file Review.FileChange
---@return string
local function key_of(file)
  return table.concat({ file.path, file.old_blob or "", file.new_blob or "" }, "\0")
end

-- Marks keyed as `{ at = <unix seconds> }`. Re-read only when the file's
-- mtime or size moved, since the outline asks per row on every render.
---@param path string
---@return table<string, {at: integer}>
local function load(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return {}
  end
  local stamp = stat.mtime.sec .. ":" .. stat.mtime.nsec .. ":" .. stat.size
  if cache.path == path and cache.stamp == stamp then
    return cache.set
  end
  local set = {}
  local fd = io.open(path, "r")
  if fd then
    local ok, decoded = pcall(vim.json.decode, fd:read("*a"))
    fd:close()
    -- A half-written or hand-edited file reads as no marks rather than
    -- breaking every outline render.
    if ok and type(decoded) == "table" then
      set = decoded
    end
  end
  cache = { path = path, stamp = stamp, set = set }
  return set
end

---@param file Review.FileChange
---@return boolean
function M.is_reviewed(file)
  local path = store_path()
  return path ~= nil and load(path)[key_of(file)] ~= nil
end

-- Flip a file's mark; returns the new state (nil when there is no git dir
-- to store marks in).
---@param file Review.FileChange
---@return boolean?
function M.toggle(file)
  local path = store_path()
  if not path then
    return nil
  end
  -- Re-read from disk (not the cache) so a concurrent nvim's marks survive.
  cache = { path = nil, stamp = nil, set = {} }
  local set = vim.deepcopy(load(path))
  local key = key_of(file)
  local now_reviewed = set[key] == nil
  set[key] = now_reviewed and { at = os.time() } or nil
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local tmp = path .. ".tmp." .. vim.uv.os_getpid()
  local fd = assert(io.open(tmp, "w"))
  fd:write(vim.json.encode(set))
  fd:close()
  assert(vim.uv.fs_rename(tmp, path))
  cache = { path = nil, stamp = nil, set = {} }
  vim.api.nvim_exec_autocmds("User", { pattern = "ReviewReviewedChanged", modeline = false })
  return now_reviewed
end

-- How many of `files` are marked reviewed.
---@param files Review.FileChange[]
---@return integer
function M.count(files)
  local path = store_path()
  if not path then
    return 0
  end
  local set = load(path)
  local n = 0
  for _, f in ipairs(files) do
    if set[key_of(f)] ~= nil then
      n = n + 1
    end
  end
  return n
end

return M
