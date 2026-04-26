---@class Config.RootUtil
local RootUtil = {}

local ROOT_PATTERNS = { ".git", "lua" }
local PACKAGE_PATTERNS = { "pkg.json", "package.json", "Cargo.toml" }
local WORKSPACE_PATTERNS = {
  "lazy-lock.json",
  "nvim-pack-lock.json",
  "yarn.lock",
  "package-lock.json",
  "pnpm-lock.yaml",
  "bun.lockb",
  "Cargo.lock",
}

---@param buf integer Buffer number to resolve the LSP root for.
---@return string?
local function resolve_lsp_root(buf)
  local bufpath = vim.api.nvim_buf_get_name(buf)
  if bufpath == "" or bufpath == nil then
    return nil
  end
  bufpath = vim.fs.normalize(bufpath)

  local roots = {}
  local clients = vim.lsp.get_clients({ bufnr = buf })
  for _, client in ipairs(clients) do
    if client.workspace_folders then
      for _, folder in ipairs(client.workspace_folders) do
        table.insert(roots, vim.uri_to_fname(folder.uri))
      end
    end
    if client.root_dir then
      table.insert(roots, client.root_dir)
    end
  end
  for _, root in ipairs(roots) do
    root = vim.fs.normalize(root)
    if bufpath:find(root, 1, true) == 1 then
      return root
    end
  end
end

---@enum (key) Config.RootUtil.Scope
-- Scope for resolving a root directory relative to a buffer.
local Scope = {
  git = "git", -- nearest .git root or cwd.
  root = "root", -- LSP root, or nearest .git root, or nearest parent with a root pattern, or cwd.
  workspace = "workspace", -- LSP root, or nearest parent with a workspace or root pattern, or cwd.
  package = "package", -- nearest parent with a package, workspace, or root pattern, or cwd.
}

RootUtil.Scope = Scope

-- Resolve a root path for the specified `scope` relative to the given `buf`.
-- If a root path cannot be found, falls back to `vim.uv.cwd()`
---@param scope Config.RootUtil.Scope? Optional scope that determines the method used to resolve the root:
-- `"git"`: nearest .git root or cwd.
-- `"root"`: LSP root, or nearest .git root, or nearest parent with a root pattern, or cwd.
-- `"workspace"`: LSP root, or nearest parent with a workspace or root pattern, or cwd.
-- `"package"`: nearest parent with a package, workspace, or root pattern, or cwd.
--
-- Defaults to `"root"`.
---@param buf integer? Optional buffer number to resolve the root for.
-- Defaults to the current buffer.
function RootUtil.root(scope, buf)
  scope = scope or RootUtil.Scope.root
  buf = buf or vim.api.nvim_get_current_buf()
  local res = nil
  if scope == Scope.git then
    res = vim.fs.root(buf, ".git")
  elseif scope == Scope.root then
    res = resolve_lsp_root(buf) or vim.fs.root(buf, ROOT_PATTERNS)
  elseif scope == Scope.workspace then
    res = resolve_lsp_root(buf) or vim.fs.root(buf, { WORKSPACE_PATTERNS, ROOT_PATTERNS })
  elseif scope == Scope.package then
    res = vim.fs.root(buf, { PACKAGE_PATTERNS, WORKSPACE_PATTERNS, ROOT_PATTERNS })
  end
  return res or vim.uv.cwd()
end

return RootUtil
