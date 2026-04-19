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

if vim.env.FNM_DIR then
	vim.g.node_host_prog = vim.fs.joinpath(vim.fn.expand(vim.env.FNM_DIR), "aliases", "default", "bin", "node")
	vim.g.copilot_node_command = vim.g.node_host_prog
end

vim.g.pager = vim.env.KITTY_SCROLLBACK_NVIM == "true"

require("config")
