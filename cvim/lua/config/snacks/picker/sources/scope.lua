---@module "snacks"

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
    resolved = Config.root("git")
  elseif scope == "workspace" then
    resolved = Config.root("workspace")
  elseif scope == "package" then
    resolved = Config.root("package")
  else
    resolved = opts and opts.cwd or Config.root("cwd")
  end

  return resolved or Config.root()
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
    title = title .. " [" .. Config.smart_shorten_path(cwd) .. "]"
  end
  return title
end

---@param title string
local function scope(title)
  ---@param opts PickerConfigWithScope
  return function(opts)
    opts = opts or {}
    local cwd = get_scope_dir(opts)
    opts.title = get_title(title, opts.scope, cwd)
    if opts.scope or cwd then
      opts.cwd = cwd
      if type(opts.filter) == "table" then
        opts.filter.cwd = cwd
      end
    end
    return opts
  end
end

return scope
