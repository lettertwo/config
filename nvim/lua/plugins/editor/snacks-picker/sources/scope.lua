---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local scope_sources = {}

---@alias FindScope 'cwd' | 'root' | 'workspace'  | 'package'
---@alias FindSource 'files' | 'packages' | 'node_modules' | 'plugins'

---@class PickerConfigWithScope: snacks.picker.Config
---@field scope FindScope?

local WORKSPACE_PATTERNS = { "lua", "yarn.lock", "package-lock.json", "pnpm-lock.yaml", "bun.lockb" }
local PACKAGE_PATTERNS = { "package.json", "Cargo.toml" }

---@param scope_or_opts FindScope | PickerConfigWithScope
---@param opts snacks.picker.Config?
---@return string? cwd
local function get_scope_dir(scope_or_opts, opts)
  local scope = type(scope_or_opts) == "string" and scope_or_opts or scope_or_opts.scope

  if scope == nil then
    return nil
  end

  local resolved
  if scope == "root" then
    resolved = LazyVim.root.git()
  elseif scope == "workspace" then
    resolved = LazyVim.root.detectors.lsp(0)[1] or LazyVim.root.detectors.pattern(0, WORKSPACE_PATTERNS)[1]
  elseif scope == "package" then
    -- TODO: resolve relative opts.cwd, if it exists
    resolved = LazyVim.root.detectors.pattern(0, PACKAGE_PATTERNS)[1]
      or LazyVim.root.detectors.pattern(0, WORKSPACE_PATTERNS)[1]
  else
    resolved = opts and opts.cwd or LazyVim.root.detectors.cwd()[1]
  end

  return resolved or LazyVim.root.get()
end

---@param source string
---@param scope FindScope?
---@param cwd string?
---@return string
local function get_title(source, scope, cwd)
  local title = source:gsub("^%l", string.upper)
  if scope ~= nil then
    title = title .. " in " .. scope
  end
  if cwd ~= nil then
    title = title .. " [" .. require("util").smart_shorten_path(cwd) .. "]"
  end
  return title
end

scope_sources.files = {
  ---@param opts PickerConfigWithScope
  config = function(opts)
    local scope = opts and opts.scope
    local cwd = get_scope_dir(opts)
    opts.title = get_title("files", scope, cwd)
    if scope or cwd then
      opts.cwd = cwd
    end
    return opts
  end,
}

scope_sources.recent = {
  ---@param opts PickerConfigWithScope
  config = function(opts)
    local scope = opts and opts.scope
    local cwd = get_scope_dir(opts)
    opts.title = get_title("recent", scope, cwd)
    if scope or cwd then
      opts.cwd = cwd
      opts.filter = vim.tbl_deep_extend("force", opts.filter or {}, {
        cwd = cwd,
      })
    end
    return opts
  end,
}

scope_sources.switch = {
  ---@param opts PickerConfigWithScope
  config = function(opts)
    local scope = opts and opts.scope
    local cwd = get_scope_dir(opts)
    opts.title = get_title("switch", scope, cwd)
    if scope or cwd then
      opts.cwd = cwd
      opts.filter = vim.tbl_deep_extend("force", opts.filter or {}, {
        cwd = cwd,
      })
    end
    return opts
  end,
}

return scope_sources
