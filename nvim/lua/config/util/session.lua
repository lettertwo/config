---@class Config.SessionUtil
local SessionUtil = {}

---@type table<string, string>
local _basename_cache = {}

function SessionUtil.get_git_branch()
  local git_dir = vim.fs.find(".git", { path = vim.fn.getcwd(), upward = true, type = "directory" })[1]
  if not git_dir then
    return nil
  end
  local f = io.open(git_dir .. "/HEAD", "r")
  if not f then
    return nil
  end
  local content = f:read("*l")
  f:close()
  return content and content:match("ref: refs/heads/(.+)")
end

function SessionUtil.get_session_basename()
  -- Implementation based on `persistence.current()`.
  local cwd = vim.fn.getcwd()
  if _basename_cache[cwd] then
    return _basename_cache[cwd]
  end
  local name = cwd:gsub("[\\/:]+", "%%")
  local branch = SessionUtil.get_git_branch()
  if branch and branch ~= "main" and branch ~= "master" then
    name = name .. "%%" .. branch:gsub("[\\/:]+", "%%")
  end
  _basename_cache[cwd] = name

  -- Invalidate the cache when the directory changes or the editor gains focus.
  -- This is conservative, but makes it more likely that we won't see a stale session name.
  vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained" }, {
    once = true,
    callback = function()
      _basename_cache = {}
    end,
  })

  return name
end

function SessionUtil.get_session_filename()
  return SessionUtil.get_session_basename() .. ".vim"
end

function SessionUtil.get_session_file()
  return vim.fs.joinpath(vim.fn.stdpath("state"), "sessions", SessionUtil.get_session_filename())
end

function SessionUtil.get_session_shadafilename()
  return SessionUtil.get_session_basename() .. ".shada"
end

function SessionUtil.get_session_shadafile()
  return vim.fs.joinpath(vim.fn.stdpath("state"), "shada", SessionUtil.get_session_filename())
end

function SessionUtil.load_last_session()
  local ok, MiniSessions = pcall(require, "mini.sessions")
  if not ok then
    vim.notify("mini.sessions not found, cannot load last session", vim.log.levels.WARN)
  end
  ok = pcall(MiniSessions.read, SessionUtil.get_session_filename())
  if not ok then
    vim.notify("No previous session found", vim.log.levels.INFO)
  end
end

function SessionUtil.get_active_session()
  local this_session = vim.v.this_session
  if this_session == "" then
    return nil
  end
  return this_session
end

return SessionUtil
