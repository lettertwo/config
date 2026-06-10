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

return {
  "folke/snacks.nvim",
  -- stylua: ignore
  keys = {
    { "<leader>f.", LazyVim.pick("files", { scope = "package" }),   desc = "Find Files (package)" },
    { "<leader>fw", LazyVim.pick("files", { scope = "workspace" }), desc = "Find Files (workspace)" },
    { "<leader>ff", LazyVim.pick("files", { scope = "cwd" }),       desc = "Find Files (cwd)" },
    { "<leader>fF", LazyVim.pick("files", { scope = "root" }),      desc = "Find Files (root dir)" },

    { "<leader>fr", LazyVim.pick("recent", { scope = "workspace" }), desc = "Recent (workspace)" },
    { "<leader>fR", LazyVim.pick("recent", { scope = "root" }),      desc = "Recent (root)" },

    { "<leader>sg", LazyVim.pick("grep", { scope = "workspace" }), desc = "Grep (workspace)" },
    { "<leader>sG", LazyVim.pick("grep", { scope = "root" }),      desc = "Grep (root)" },
    { "<leader>s.", LazyVim.pick("grep", { scope = "package" }),   desc = "Grep (package)" },
    { "<leader>/",  LazyVim.pick("grep", { scope = "root" }),      desc = "Grep (root)" },
  },
  ---@type snacks.Config
  opts = {
    picker = {
      -- stylua: ignore
      sources = {
        buffers = { config = scope("buffers") },
        files   = { config = scope("files") },
        recent  = { config = scope("recent") },
        grep    = { config = scope("grep") },
        switch  = { config = scope("switch") },
      },
    },
  },
}
