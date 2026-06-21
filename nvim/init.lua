local startime = vim.uv.hrtime()

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Disable common built-in plugins
vim.g.loaded_2html_plugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1

require("config")

-- App framework: must be required after Config so app modules can use Config
-- utilities, but before plugin/ files load so App.is_default() is available
-- for gating.
_G.App = require("app")

-- Eager load phase: the default app registers its FileType autocmds (LSP,
-- completion, treesitter-editing) here — before plugin/ auto-sourcing and
-- before UIEnter — so they catch the first argv buffer's FileType event.
-- Lean apps (mergetool, scrollback) have no load() and this is a no-op.
App.load(vim.g.app or "default")

Config.once("UIEnter", function()
  -- Boot the root app (standalone context).  vim.g.app is set via --cmd by
  -- the shell wrapper / gitconfig cmd strings; unset = normal editing.
  App.launch(vim.g.app or "default", { context = "standalone" })

  ---@diagnostic disable-next-line: inject-field
  Config._stats = Config._stats or {}
  Config._stats.startuptime = (vim.uv.hrtime() - startime) / 1e6
end)
