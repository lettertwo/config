---@class App
---@field name string
---@field load? fun(self): nil     -- optional eager-load phase (runs during init)
---@field run fun(self, args: table): nil
---@field teardown fun(self): nil

---@class AppFramework
---@field _current App|nil   the currently-running app instance
local M = {
  _current = nil,
}

-- Accept app name from VIM_APP env var as a fallback for gitconfig cmd
-- invocations (gitconfig strips "..." pairs, making --cmd Lua string quoting
-- unreliable; a bare inline env var like VIM_APP=mergetool has no quoting issues).
if not vim.g.app and vim.env.VIM_APP and vim.env.VIM_APP ~= "" then
  vim.g.app = vim.env.VIM_APP
end

-- D8: disable shada early for non-default standalone apps so it is never
-- read during startup (shada is loaded after init scripts run).
if vim.g.app and vim.g.app ~= "" and vim.g.app ~= "default" then
  vim.o.shada = ""
end

-- Eagerly loads an app's plugin directory during init, before plugin/ auto-source
-- and before UIEnter. Registers FileType autocmds early enough to catch the first
-- argv buffer. Two modes:
--   explicit: app defines load() → called directly, full control, no auto-scan.
--   auto:     no load() → scans lua/app/<name>/plugins/*.lua alphabetically.
---@param name string
function M.load(name)
  local ok, app = pcall(require, "app." .. name)
  if not ok then
    return -- silent: launch() will report the error with context at UIEnter
  end

  if app.load then
    app:load()
    return
  end

  -- Auto-scan plugins/ directory alphabetically.
  local plugins_dir = vim.fn.stdpath("config") .. "/lua/app/" .. name .. "/plugins"
  local handle = vim.uv.fs_opendir(plugins_dir, nil, 64)
  if not handle then
    return
  end
  local entries = vim.uv.fs_readdir(handle)
  vim.uv.fs_closedir(handle)
  if not entries then
    return
  end
  table.sort(entries, function(a, b)
    return a.name < b.name
  end)
  for _, entry in ipairs(entries) do
    if entry.type == "file" and entry.name:match("%.lua$") then
      local stem = entry.name:sub(1, -5)
      require("app." .. name .. ".plugins." .. stem)
    end
  end
end

-- Returns true when the default app is the root app (plain nvim launch).
function M.is_default()
  return not vim.g.app or vim.g.app == "" or vim.g.app == "default"
end

-- Quit nvim with an app-controlled exit code (D5).
-- code = 0  →  write all changed buffers and exit (success)
-- code ~= 0 →  cquit (failure; git mergetool inspects exit code)
---@param code? integer  defaults to 0
function M.quit(code)
  code = code or 0
  if code == 0 then
    -- xa writes all modified named bufs; unmodified bufs are just closed
    vim.cmd("silent! xa")
  else
    vim.cmd("cquit " .. code)
  end
end

-- Launch an app by name.
-- In standalone context the app owns the process (non-cancelable, exit = quit).
-- In embedded context a new tabpage is opened and the previous one is restored
-- on close (cancelable).
---@param name string
---@param opts? { context?: "standalone"|"embedded", args?: table }
function M.launch(name, opts)
  opts = opts or {}
  local context = opts.context or "embedded"
  local args = opts.args or {}

  local ok, app = pcall(require, "app." .. name)
  if not ok then
    -- Trim the verbose Lua module search-path from the error message.
    local short_err = tostring(app):match("^([^\n]+)") or tostring(app)
    vim.notify(
      string.format("[App] unknown app %q — falling back to default\n(%s)", name, short_err),
      vim.log.levels.ERROR
    )
    if name ~= "default" then
      M.launch("default", { context = context, args = args })
    end
    return
  end

  if context == "standalone" then
    M._launch_standalone(app, args)
  else
    M._launch_embedded(app, args)
  end
end

-- Internal: standalone launch.
---@param app App
---@param args table
function M._launch_standalone(app, args)
  M._current = app

  -- D7: suppress argv file auto-open — wipe any [No Name] buffer that nvim
  -- created before our app had a chance to build its own layout.
  -- Skip for the default app: it relies on buffer 1 for the snacks dashboard
  -- and normal editing; wiping it would destroy the dashboard immediately.
  if not M.is_default() then
    vim.schedule(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if
          vim.api.nvim_buf_is_valid(buf)
          and vim.api.nvim_buf_get_name(buf) == ""
          and not vim.bo[buf].modified
          and vim.fn.bufwinid(buf) ~= -1
        then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end)
  end

  -- Teardown on VimLeavePre (fires before any exit, including cquit).
  vim.api.nvim_create_autocmd("VimLeavePre", {
    once = true,
    group = vim.api.nvim_create_augroup("AppStandalone", { clear = true }),
    callback = function()
      if M._current and M._current.teardown then
        pcall(M._current.teardown, M._current)
      end
    end,
  })

  app:run(args)
end

-- Internal: embedded launch.
---@param app App
---@param args table
function M._launch_embedded(app, args)
  local prev_tabpage = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabnew")

  -- Track teardown so close() is idempotent.
  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if app.teardown then
      pcall(app.teardown, app)
    end
    -- Close the app tabpage (all its windows) then restore the host tabpage.
    pcall(vim.cmd.tabclose)
    if vim.api.nvim_tabpage_is_valid(prev_tabpage) then
      vim.api.nvim_set_current_tabpage(prev_tabpage)
    end
  end

  -- Also hook TabClosed so closing the tab by any means (e.g. :tabclose) cleans up.
  vim.api.nvim_create_autocmd("TabClosed", {
    once = true,
    group = vim.api.nvim_create_augroup("AppEmbedded_" .. tostring(prev_tabpage), { clear = true }),
    callback = function()
      close()
    end,
  })

  app:run(args)
end

-- `:App <name> [args...]` command — launches in embedded context by default.
vim.api.nvim_create_user_command("App", function(cmd_opts)
  local parts = vim.split(vim.trim(cmd_opts.args), "%s+", { trimempty = true })
  local name = table.remove(parts, 1)
  if not name or name == "" then
    vim.notify("[App] usage: :App <name> [args...]", vim.log.levels.WARN)
    return
  end
  M.launch(name, { context = "embedded", args = parts })
end, {
  nargs = "+",
  desc = "Launch an app (embedded by default)",
  complete = function()
    -- Enumerate known apps by scanning lua/app/ subdirectories.
    local app_dir = vim.fn.stdpath("config") .. "/lua/app"
    local names = {}
    local handle = vim.uv.fs_opendir(app_dir, nil, 32)
    if handle then
      local entries = vim.uv.fs_readdir(handle)
      vim.uv.fs_closedir(handle)
      if entries then
        for _, entry in ipairs(entries) do
          if entry.type == "directory" then
            table.insert(names, entry.name)
          end
        end
      end
    end
    return names
  end,
})

return M
