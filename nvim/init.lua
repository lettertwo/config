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

vim.g.pager = vim.env.KITTY_SCROLLBACK_NVIM == "true"

require("config")

Config.once("UIEnter", function()
  ---@diagnostic disable-next-line: inject-field
  Config._stats = Config._stats or {}
  Config._stats.startuptime = (vim.uv.hrtime() - startime) / 1e6
end)
