-- Uncommitted-changes source: one Changeset built from the three-way
-- `git diff` fan-out (worktree↔HEAD combined, index↔HEAD staged,
-- worktree↔index unstaged) plus untracked files.
--
-- The staged/unstaged sub-diffs are attached per file now even though the M1
-- renderer only draws the combined view — M5 staging consumes them.

---@class Review.Changeset
---@field id string
---@field title string
---@field base_ref string
---@field head_ref string
---@field files Review.FileChange[]
---@field head_sha string

---@class Review.Source
---@field kind string
---@field cwd string
---@field load fun(self: Review.Source, callback: fun(changesets: Review.Changeset[]?, err: string?))
---@field refresh fun(self: Review.Source, callback: fun(changesets: Review.Changeset[]?, err: string?))
---@field can_stage fun(self: Review.Source): boolean

local M = {}
local git = require("app.review.diff.git")
local parser = require("app.review.diff.parser")

-- Merge the three parsed diffs into one FileChange list keyed by path.
---@param combined_raw string
---@param staged_raw string
---@param unstaged_raw string
---@param untracked string[]
---@return Review.FileChange[]
local function merge_files(combined_raw, staged_raw, unstaged_raw, untracked)
  local untracked_set = {}
  for _, p in ipairs(untracked or {}) do
    untracked_set[p] = true
  end

  local combined_by_path = {}
  for _, f in ipairs(parser.parse(combined_raw or "")) do
    combined_by_path[f.path] = f
  end
  local staged_by_path = {}
  for _, f in ipairs(parser.parse(staged_raw or "")) do
    staged_by_path[f.path] = f
  end
  local unstaged_by_path = {}
  for _, f in ipairs(parser.parse(unstaged_raw or "")) do
    unstaged_by_path[f.path] = f
  end

  -- Union of all paths so files that are staged but have no net worktree↔HEAD
  -- diff (staged then worktree-reverted) still appear.
  local all_paths = {}
  local seen_paths = {}
  local function add_path(p)
    if not seen_paths[p] then
      seen_paths[p] = true
      table.insert(all_paths, p)
    end
  end
  for p in pairs(combined_by_path) do add_path(p) end
  for p in pairs(staged_by_path) do add_path(p) end
  for p in pairs(unstaged_by_path) do add_path(p) end

  local files = {}
  for _, path in ipairs(all_paths) do
    -- Prefer the combined entry; synthesize when absent (staged-then-reverted).
    local primary = combined_by_path[path] or {
      path = path,
      old_path = (staged_by_path[path] or {}).old_path,
      status = (staged_by_path[path] or unstaged_by_path[path] or {}).status or "M",
      hunks = {},
      changeset_id = "",
      base_ref = "",
      head_ref = "",
    }

    if untracked_set[path] then
      primary.status = "U"
    end

    local s = staged_by_path[path]
    if s and #s.hunks > 0 then
      s.base_ref = "HEAD"
      s.head_ref = "INDEX"
      s.changeset_id = ""
      primary.staged_change = s
    end

    local u = unstaged_by_path[path]
    if u and #u.hunks > 0 then
      u.base_ref = "INDEX"
      u.head_ref = "WORKTREE"
      u.changeset_id = ""
      primary.unstaged = u
    end

    -- Outline summary fields (M3): staged=true when fully staged,
    -- staged_hunks when partially staged.
    if s and #s.hunks > 0 then
      if u and #u.hunks > 0 then
        primary.staged_hunks = s.hunks
      else
        primary.staged = true
      end
    end

    table.insert(files, primary)
  end

  table.sort(files, function(a, b)
    return a.path < b.path
  end)
  return files
end

-- Exposed for unit tests only.
M._merge_files = merge_files

---@param opts {cwd: string}
---@return Review.Source
function M.new(opts)
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()

  local self = {
    kind = "uncommitted",
    cwd = cwd,
  }

  ---@param callback fun(changesets: Review.Changeset[]?, err: string?)
  function self:load(callback)
    git.head_sha(cwd, function(head_sha, err)
      if err then
        callback(nil, err)
        return
      end
      git.diff_uncommitted(cwd, function(combined, staged, unstaged_only, untracked, err2)
        if err2 then
          callback(nil, err2)
          return
        end
        local files = merge_files(combined, staged, unstaged_only, untracked)
        local changeset_id = "uncommitted"
        for _, f in ipairs(files) do
          f.changeset_id = changeset_id
          f.base_ref = "HEAD"
          f.head_ref = "WORKTREE"
        end
        ---@type Review.Changeset
        local changeset = {
          id = changeset_id,
          title = "Uncommitted Changes",
          base_ref = "HEAD",
          head_ref = "WORKTREE",
          files = files,
          head_sha = head_sha or "",
        }
        callback({ changeset }, nil)
      end)
    end)
  end

  function self:refresh(callback)
    self:load(callback)
  end

  function self:can_stage()
    return true
  end

  return self
end

return M
