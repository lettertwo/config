-- lvim.builtin.alpha.mode = "startify"

-- Don't wrap text, but highlight long lines
vim.opt.textwidth = 80 -- the width that'll be used for wrapping (gq)
vim.opt.colorcolumn:append("+1") -- color column 80 so I know when my line's too long
vim.opt.formatoptions:remove("t") -- do not automatically wrap text when typing
vim.opt.wrap = false -- Disable line wrapping

-- Keep lines below cursor when scrolling
vim.opt.scrolloff = 10
vim.opt.sidescrolloff = 15

-- Show line numbers, relative normally, nonrelative when inserting
vim.opt.number = true
vim.opt.relativenumber = true
lvim.autocommands.custom_groups = {
	{ "InsertEnter", "*", ":set norelativenumber" },
	{ "InsertLeave", "*", ":set relativenumber" },
}

-- Insert mode completion setting
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- Command completion
vim.opt.wildmenu = true -- visual autocomplete for command menu
vim.opt.wildmode = "longest:full,full" -- autocomplete full on first tab, full on second tab

-- Set grep default grep command with ripgrep
vim.opt.grepprg = "rg --vimgrep --follow"
vim.opt.errorformat:append("%f:%l:%c%p%m")

-- general
lvim.log.level = "warn"
lvim.format_on_save = true
lvim.line_wrap_cursor_movement = true

lvim.colorscheme = "laserwave"

-- Don't highlight trailing whitespace for these filetypes
vim.g.better_whitespace_filetypes_blacklist = {
	"diff",
	"git",
	"gitcommit",
	"unite",
	"qf",
	"help",
	"markdown",
	"fugitive",
	"dashboard",
	"NvimTree",
	"Outline",
	"Trouble",
}

-- Don't show gitblame virtual text for these filetypes.
vim.g.gitblame_ignored_filetypes = { "NvimTree", "Outline", "Trouble" }

-- folding
vim.opt.foldcolumn = "1"
vim.opt.foldlevelstart = 99

lvim.builtin.notify.active = true
lvim.builtin.terminal.active = true
lvim.builtin.dap.active = true

require("keys")
require("lsp")
require("plugins")

-- Autocommands (https://neovim.io/doc/user/autocmd.html)
-- lvim.autocommands.custom_groups = {
--   { "BufWinEnter", "*.lua", "setlocal ts=8 sw=8" },
-- }
