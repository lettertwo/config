-- Reloads the annotation store when claude-annotations/ changes on disk
-- outside of nvim: the annotations skill appending resolutions.jsonl, or
-- someone editing either file by hand. Without this, the buffer only picks
-- up such a change on its next unrelated store mutation or `:e`.
--
-- macOS FSEvents (what `vim.uv.new_fs_event` rides on there) reports at
-- directory granularity, not per file, so one watcher on the directory
-- catches edits to either file inside it. A skill run can append several
-- resolution rows in a burst; the debounce collapses that into one reload
-- instead of one per write.

local Store = require("config.annotations.store")

local Watch = {}

local DEBOUNCE_MS = 100

local fs_event = nil
local debounce_timer = nil

local function reload()
  Store._reset_cache()
  Store.load()
  vim.api.nvim_exec_autocmds("User", { pattern = "AnnotationsChanged", data = { ids = {} } })
end

local function on_fs_event()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
  end
  debounce_timer = vim.uv.new_timer()
  debounce_timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(reload))
end

function Watch.active()
  return fs_event ~= nil
end

-- Starts watching claude-annotations/ for the worktree containing `cwd`
-- (defaults to nvim's own cwd). A no-op outside a git worktree, and also
-- when the directory does not exist yet: the store creates it on the first
-- save, so a repo that has never had an annotation gets no watcher and no
-- stray directory. Call again after a store mutation to pick it up.
---@param cwd string?
function Watch.start(cwd)
  Watch.stop()
  local git_dir = Store.git_dir(cwd or vim.uv.cwd())
  if not git_dir then
    return
  end
  local dir = vim.fs.joinpath(git_dir, "claude-annotations")
  if vim.fn.isdirectory(dir) == 0 then
    return
  end

  fs_event = vim.uv.new_fs_event()
  fs_event:start(dir, {}, function(err)
    if not err then
      on_fs_event()
    end
  end)
end

function Watch.stop()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end
  if fs_event then
    fs_event:stop()
    fs_event:close()
    fs_event = nil
  end
end

return Watch
