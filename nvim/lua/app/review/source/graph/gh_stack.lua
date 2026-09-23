-- gh-stack-backed stack graph: reads gh-stack's `gh-stack` JSON file
-- (github/gh-stack, https://github.com/github/gh-stack) rather than
-- shelling out to `gh stack`. gh-stack keeps its file per checkout rather
-- than in the common dir, so a linked worktree's copy is a real file, not a
-- symlink, unless something has already canonicalized it — read every one
-- of those as a union with the common-dir copy.

local M = {}
local git = require("app.review.diff.git")
local walk = require("app.review.source.graph.walk")

local FILE_NAME = "gh-stack"

-- Read+parse with retry: gh-stack writes by truncating the file in place, so
-- a reader can catch it half-written during any concurrent `gh stack`
-- command. Three attempts, 25ms apart, then the file is skipped. A
-- schemaVersion above what this reader understands is not a race — it is a
-- format nvim has never seen, and no retry fixes that, so it raises instead
-- of being swallowed like a truncated read.
---@param path string
---@return table?
local function read_stack_file(path)
  for attempt = 1, 3 do
    local ok_read, lines = pcall(vim.fn.readfile, path)
    if ok_read then
      local ok_decode, data = pcall(vim.json.decode, table.concat(lines, "\n"))
      if ok_decode and type(data) == "table" then
        local version = data.schemaVersion or 1
        if version > 1 then
          error(("gh-stack file %s has schemaVersion %d, newer than this reader understands"):format(path, version))
        end
        return data
      end
    end
    if attempt < 3 then
      vim.wait(25)
    end
  end
  return nil
end

-- Every <common>/worktrees/*/gh-stack that is a regular file rather than a
-- symlink, in directory-name order. A worktree admin dir here is a symlink
-- once something has canonicalized it (nvim never plants that symlink
-- itself); a dangling symlink to a not-yet-created canonical file is a valid
-- state and must not be followed, only checked by its own link-or-not type.
---@param common_dir string
---@return string[]
local function unlinked_worktree_files(common_dir)
  local worktrees_dir = common_dir .. "/worktrees"
  if vim.fn.isdirectory(worktrees_dir) ~= 1 then
    return {}
  end
  local names = vim.fn.readdir(worktrees_dir) or {}
  table.sort(names)
  local files = {}
  for _, name in ipairs(names) do
    local path = worktrees_dir .. "/" .. name .. "/" .. FILE_NAME
    local lstat = vim.uv.fs_lstat(path)
    if lstat and lstat.type == "file" then
      table.insert(files, path)
    end
  end
  return files
end

-- number when nonzero, else id when non-empty, else the trunk plus first
-- branch. Two files can describe the same stack (canonical plus a stale
-- worktree copy); whichever is discovered first wins wholesale, since
-- merging two disagreeing ordered branch lists has no defined meaning.
---@param stack table
---@return string
local function stack_identity(stack)
  if stack.number and stack.number ~= 0 then
    return "number:" .. tostring(stack.number)
  end
  if stack.id and stack.id ~= "" then
    return "id:" .. stack.id
  end
  local first = stack.branches and stack.branches[1] and stack.branches[1].branch or ""
  return "trunk:" .. (stack.trunk.branch or "") .. ":" .. first
end

-- Fold a stack entry's linear branch list into the shared parent map.
-- branches[0]'s parent is the trunk; branches[i]'s parent is branches[i-1].
-- The file's own `head` per branch is a snapshot from the last sync and goes
-- stale the moment a plain git commit lands, so it is carried through only
-- as the walk's head_rev fallback field — base_ref/head_ref never read it.
---@param stack table
---@param by_branch table<string, table>
---@param pr_numbers table<string, integer>
local function fold_stack(stack, by_branch, pr_numbers)
  local parent = stack.trunk.branch
  for _, br in ipairs(stack.branches or {}) do
    if br.branch and br.branch ~= "" and not by_branch[br.branch] then
      by_branch[br.branch] = {
        branch = br.branch,
        parent = parent,
        head_rev = br.head or "",
        parent_rev = br.base or "",
      }
      if br.pullRequest and br.pullRequest.number then
        pr_numbers[br.branch] = br.pullRequest.number
      end
    end
    parent = br.branch
  end
end

---@param cwd string
---@param common_dir? string  common git dir (resolved by the factory; falls
---                           back to resolving it here)
---@param branch? string  focus branch (defaults to the checked-out branch)
---@return Review.StackGraph
function M.new(cwd, common_dir, branch)
  local self = {}
  common_dir = common_dir or git.common_dir_sync(cwd) or (cwd .. "/.git")
  branch = branch or git.current_branch_sync(cwd)

  local paths = {}
  local canonical = common_dir .. "/" .. FILE_NAME
  if vim.fn.filereadable(canonical) == 1 then
    table.insert(paths, canonical)
  end
  vim.list_extend(paths, unlinked_worktree_files(common_dir))

  local seen = {}
  local by_branch = {}
  local pr_numbers = {}
  for _, path in ipairs(paths) do
    local data = read_stack_file(path)
    if data then
      for _, stack in ipairs(data.stacks or {}) do
        -- A stack entry missing a well-formed trunk is skipped, not fatal —
        -- one bad entry doesn't blind the read of the rest of the file.
        if type(stack.trunk) == "table" and type(stack.trunk.branch) == "string" and stack.trunk.branch ~= "" then
          local identity = stack_identity(stack)
          if not seen[identity] then
            seen[identity] = true
            fold_stack(stack, by_branch, pr_numbers)
          end
        end
      end
    end
  end

  local nodes = walk.walk(by_branch, branch)

  function self:nodes()
    return nodes
  end

  function self:base_ref(node)
    return node.parent_rev
  end

  function self:head_ref(node)
    return "refs/heads/" .. node.branch
  end

  function self:metadata(node)
    return { pr_number = pr_numbers[node.branch] }
  end

  return self
end

return M
