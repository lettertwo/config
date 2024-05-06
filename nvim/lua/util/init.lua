-- Adapted from: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/util/init.lua

---@class ConfigUtil: LazyUtilCore, BufferKeymapUtil, HoverUtil
local ConfigUtil =
  vim.tbl_extend("error", require("lazy.core.util"), require("util.buffer_keymap"), require("util.hover"))

ConfigUtil.root_patterns = { ".git", "lua" }

---@param str string
function ConfigUtil.capcase(str)
  return str:sub(1, 1):upper() .. str:sub(2)
end

---@param str string
---@param group string
function ConfigUtil.format_highlight(str, group)
  return "%#" .. group .. "#" .. str .. "%*"
end

--- Gets the buffer number of every visible buffer
--- @return integer[]
function ConfigUtil.visible_buffers()
  return vim.tbl_map(vim.api.nvim_win_get_buf, vim.api.nvim_list_wins())
end

function ConfigUtil.lsp_active()
  for _, client in pairs(vim.lsp.get_clients()) do
    if client.server_capabilities then
      return true
    end
  end
  return false
end

function ConfigUtil.close_floats()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
      vim.api.nvim_win_close(win, false)
    end
  end
end

function ConfigUtil.clear_highlights()
  vim.cmd("nohlsearch")
  if ConfigUtil.lsp_active() then
    vim.lsp.buf.clear_references()
    for _, buffer in pairs(ConfigUtil.visible_buffers()) do
      vim.lsp.util.buf_clear_references(buffer)
    end
  end
end

function ConfigUtil.close_floats_and_clear_highlights()
  ConfigUtil.close_floats()
  if vim.bo.modifiable then
    ConfigUtil.clear_highlights()
  else
    if #vim.api.nvim_list_wins() > 1 then
      return ConfigUtil.feedkeys("<C-w>c")
    end
  end
end

---@param str string
function ConfigUtil.termcodes(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

---@param keys string
---@param mode? string
function ConfigUtil.feedkeys(keys, mode)
  if mode == nil then
    mode = "in"
  end
  return vim.api.nvim_feedkeys(ConfigUtil.termcodes(keys), mode, true)
end

---@param cb fun(client, buffer)
function ConfigUtil.on_attach(cb)
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      if not (args.data and args.data.client_id) then
        return
      end
      local buffer = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      cb(client, buffer)
    end,
  })
end

---@param plugin string
function ConfigUtil.has(plugin)
  return require("lazy.core.config").plugins[plugin] ~= nil
end

---@param name string
function ConfigUtil.opts(name)
  local plugin = require("lazy.core.config").plugins[name]
  if not plugin then
    return {}
  end
  local Plugin = require("lazy.core.plugin")
  return Plugin.values(plugin, "opts", false)
end

function ConfigUtil.config_path()
  local config = vim.fn.stdpath("config") or "~/.config/nvim"
  if type(config) == "table" then
    config = config[1]
  end
  return config
end

-- returns the root directory based on:
-- * lsp workspace folders
-- * lsp root_dir
-- * root pattern of filename of the current buffer
-- * root pattern of cwd
---@return string
function ConfigUtil.get_root()
  ---@type string?
  local path = vim.api.nvim_buf_get_name(0)
  path = path ~= "" and vim.loop.fs_realpath(path) or nil
  ---@type string[]
  local roots = {}
  if path then
    for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
      local workspace = client.config.workspace_folders
      local paths = workspace and vim.tbl_map(function(ws)
        return vim.uri_to_fname(ws.uri)
      end, workspace) or client.config.root_dir and { client.config.root_dir } or {}
      for _, p in ipairs(paths) do
        local r = vim.loop.fs_realpath(p)
        if r ~= nil then
          if path:find(r, 1, true) then
            roots[#roots + 1] = r
          end
        end
      end
    end
  end
  table.sort(roots, function(a, b)
    return #a > #b
  end)
  ---@type string?
  local root = roots[1]
  if not root then
    path = path and vim.fs.dirname(path) or vim.loop.cwd()
    ---@type string?
    root = vim.fs.find(ConfigUtil.root_patterns, { path = path, upward = true })[1]
    root = root and vim.fs.dirname(root) or vim.loop.cwd()
  end
  ---@cast root string
  return root
end

--- Create a toggle function for an option or variable.
--- By default, the scope is assumed to be a buffer-local variable (`b`),
---
--- An optional function may be provided to handle the toggle.
--- If the handle returns `false`, the toggle will be cancelled.
---
---@param name string
---@param scope? string
---|'bo'  # buffer-local option
---|'b'   # buffer-local variable
---|'wo'  # window-local option
---|'w'   # window-local variable
---|'o'   # global option
---|'g'   # global variable
---@param handle? fun(value: boolean): false | nil
function ConfigUtil.create_toggle(name, scope, handle)
  scope = scope or "b"
  return function()
    local value = vim[scope][name]
    if value == nil then
      value = false
    else
      value = not value
    end

    if handle == nil or handle(value) ~= false then
      vim[scope][name] = value
      if value then
        ConfigUtil.info("Enabled " .. name, { title = scope })
      else
        ConfigUtil.warn("Disabled " .. name, { title = scope })
      end
    end
  end
end

function ConfigUtil.toggle_diagnostics()
  if vim.diagnostic.is_disabled() then
    vim.diagnostic.enable()
    ConfigUtil.info("Enabled diagnostics", { title = "Diagnostics" })
  else
    vim.diagnostic.disable()
    ConfigUtil.warn("Disabled diagnostics", { title = "Diagnostics" })
  end
end

function ConfigUtil.service_status()
  local buf = vim.api.nvim_get_current_buf()
  local buf_ft = vim.bo.filetype

  ---@class ServiceStatus
  ---@field diagnostic_providers string[]
  ---@field formatting_providers string[]
  ---@field copilot_active boolean
  ---@field treesitter_active boolean
  ---@field session_active boolean
  ---@field lazy_updates boolean
  local status = {
    diagnostic_providers = {},
    formatting_providers = {},
    copilot_active = false,
    treesitter_active = vim.treesitter.highlighter.active[buf] ~= nil and next(vim.treesitter.highlighter.active[buf]),
    session_active = require("persistence").current ~= nil,
    lazy_updates = require("lazy.status").has_updates(),
    -- TODO: check for mason updates
    -- mason_updates
  }

  -- add lsp clients
  for _, client in pairs(vim.lsp.get_clients()) do
    if client.name == "copilot" then
      status.copilot_active = true
    else
      table.insert(status.diagnostic_providers, client.name)
    end
  end

  -- add linters
  local lint_ok, lint = pcall(require, "lint")
  if lint_ok then
    local active = lint._resolve_linter_by_ft(buf_ft)
    if active then
      -- concat the active linters to the list of diagnostic providers
      for _, linter in pairs(active) do
        table.insert(status.diagnostic_providers, linter)
      end
    end
  end

  -- add formatters
  local conform_ok, conform = pcall(require, "conform")
  if conform_ok then
    local active = conform.list_formatters(buf)
    if active then
      for _, formatter in ipairs(active) do
        table.insert(status.formatting_providers, formatter)
      end
    end
    if conform.will_fallback_lsp({ bufnr = buf }) then
      table.insert(status.formatting_providers, "lsp")
    end
  end

  ---@class ServiceStatus
  return status
end

function ConfigUtil.debounce(ms, fn)
  local timer = vim.loop.new_timer()
  return function(...)
    local argv = { ... }
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(unpack(argv))
    end)
  end
end

function ConfigUtil.interval(ms, fn)
  local timer = vim.loop.new_timer()
  timer:start(ms, ms, fn)
  return function()
    timer:stop()
    timer:close()
  end
end

---@class EnsureInstalled: string[]
-- A utility for managing what is installed by Mason.
-- It is a list of names of Mason-installable packages.
--
-- If called as a function, it will add the given packages to the list.
--
-- It may be called with a string, a list of strings, or a table that maps
-- some string, e.g., filetype, to a string or list of strings.
--
-- The function will return the original spec argument, so it may be used inline
-- for configuration.
--
-- Examples:
--
-- ```lua
-- -- Install the package "rust-analyzer"
-- require("util").ensure_installed("rust-analyzer")
-- -- Install the packages "rust-analyzer" and "clangd"
-- require("util").ensure_installed({ "rust-analyzer", "clangd" })
-- -- Configure formatters by filetype, and ensure that the formatters are installed
-- formatters_by_ft = require("util").ensure_installed({ javascript = { { "prettierd", "prettier" } } })
-- ```
--
---@overload fun(spec: string): string
---@overload fun(spec: string[]): string[]
---@overload fun(spec: {[string]: string | string[] | string[][]}): {[string]: string | string[] | string[][]}
ConfigUtil.ensure_installed = {}

---@diagnostic disable-next-line: param-type-mismatch
setmetatable(ConfigUtil.ensure_installed, {
  __call = function(self, spec)
    for _, value in pairs(type(spec) == "string" and { spec } or spec) do
      if type(value) == "string" then
        if not vim.list_contains(self, value) then
          table.insert(self, value)
        end
      elseif type(value) == "table" then
        ConfigUtil.ensure_installed(value)
      else
        error("Invalid value type " .. type(value) .. " in spec")
      end
    end

    return spec
  end,
})

--- @param path string?
--- @param opts? { cwd: string?, target_width: number? }
function ConfigUtil.smart_shorten_path(path, opts)
  opts = opts or {}
  local cwd = opts.cwd
  local target_width = opts.target_width

  local Path = require("plenary.path")
  local truncate = require("plenary.strings").truncate

  if path == nil then
    path = vim.api.nvim_buf_get_name(0)
  end

  path = Path:new(path):normalize(cwd or vim.loop.cwd())

  if target_width ~= nil then
    if #path > target_width then
      path = Path:new(path):shorten(1, { -2, -1 })
    end

    if #path > target_width then
      path = Path:new(path):shorten(1, { -1 })
    end

    if #path > target_width then
      path = truncate(path, target_width, nil, -1)
    end
  end

  return path
end

local DEFAULT_TITLE_PATH_OPTS = {
  ambiguous_segments = {
    "init.lua",
    "index.js",
    "index.ts",
    "index.jsx",
    "index.tsx",
    "package.json",
    "init.rs",
    "lib.rs",
    "main.rs",
    "src",
  },
}

local SEP = package.config:sub(1, 1)

--- @param path string?
--- @param opts? { cwd: string?, target_width: number?, ambiguous_segments: string[]? }
function ConfigUtil.title_path(path, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, DEFAULT_TITLE_PATH_OPTS)
  path = ConfigUtil.smart_shorten_path(path, { cwd = opts.cwd, target_width = opts.target_width })

  local segments = vim.split(path, SEP)

  local title_path = {}

  local i = #segments

  while i > 0 do
    local segment = segments[i]
    table.insert(title_path, 1, segment)
    if not vim.list_contains(opts.ambiguous_segments, segment) then
      break
    end
    i = i - 1
  end

  return table.concat(title_path, SEP)
end

function ConfigUtil.timeago(time)
  local current_time = os.time()
  local time_difference = os.difftime(current_time, time)
  local minutes = math.floor(time_difference / 60)
  local hours = math.floor(time_difference / 3600)
  local days = math.floor(time_difference / 86400)

  if days > 0 then
    return days .. (days > 1 and " days ago" or " day ago")
  elseif hours > 0 then
    return hours .. (hours > 1 and " hours ago" or " hour ago")
  elseif minutes > 0 then
    return minutes .. (minutes > 1 and " minutes ago" or " minute ago")
  else
    return "just now"
  end
end

---@param bufnr integer
---@param force? boolean
function ConfigUtil.delete_buffer(bufnr, force)
  if force == nil then
    force = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "terminal"
  end
  local bufremove_ok, bufremove = pcall(require, "mini.bufremove")
  if bufremove_ok and bufremove then
    local ok, success = pcall(bufremove.delete, bufnr, force)
    return ok and success
  else
    local ok = pcall(vim.api.nvim_buf_delete, bufnr, { force = force })
    return ok
  end
end

function ConfigUtil.is_callable(callback)
  if type(callback) == "function" then
    return true
  end
  local cb_meta = getmetatable(callback)
  if cb_meta ~= nil then
    return ConfigUtil.is_callable(cb_meta.__call)
  end
  return false
end

return ConfigUtil
