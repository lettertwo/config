-- Adapted from: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
local icons = require("config").icons

-- Space is leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- fix markdown indentation settings
vim.g.markdown_recommended_style = 0

local opt = vim.opt

-- Magic files
opt.backup = false -- don't create backup files
opt.writebackup = false -- seriously, don't create backup files
opt.swapfile = false -- don't create swapfiles
opt.undofile = true -- enable persistent undo
opt.autowrite = true -- enable auto write
opt.confirm = true -- confirm to save changes before exiting modified buffer
opt.hidden = true -- Enable modified buffers in background

-- Default to utf-8
opt.fileencoding = "utf-8"

-- Use system clipboard
opt.clipboard = "unnamedplus"

opt.spelllang = { "en" }

-- sometimes it takes a while to realize your mistake
opt.undolevels = 10000

-- Indents and whitespace
opt.expandtab = true -- convert tabs to spaces
opt.tabstop = 2 -- insert 2 spaces for a tab
opt.smartindent = true -- autoindent more smartlier
opt.shiftwidth = 2 -- number of spaces used in autoindent
opt.shiftround = true -- Round indent
opt.joinspaces = false -- No double spaces with join after a dot

-- Search behaviors
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "nosplit" -- preview incremental substitute

-- Allow mouse interactivity
opt.mouse = "a"

-- UI settings
opt.termguicolors = true -- True color support
opt.pumheight = 10 -- reasonable popup menu height
opt.pumblend = 10 -- Popup blend
opt.cmdheight = 1 -- more command line space
opt.winminwidth = 5 -- minimum window width
opt.showmode = false -- hide the mode label (e.g., INSERT)
opt.showtabline = 0 -- never show tabline
opt.cursorline = true -- highlight the current line
opt.laststatus = 3 -- always show only one statusline
opt.showcmd = false -- hide display of last command
opt.ruler = false -- hide display of cursor location
opt.signcolumn = "yes" -- always show the sign column
opt.guifont = "monospace:h14" -- use the configured monospace font
opt.timeoutlen = 250 -- gotta type faster
opt.updatetime = 200 -- tigger CursorHold autocmds faster
opt.fillchars = {
  foldopen = icons.fold.foldopen,
  foldclose = icons.fold.foldclose,
  foldsep = icons.fold.foldsep,
  fold = icons.fold.fold,
  eob = icons.eob,
  diff = "╱",
}
opt.colorcolumn:append("+1") -- color column at textwidth so I know when my line's too long
opt.shortmess = "fFIlqx" -- from https://github.com/folke/noice.nvim/issues/300#issuecomment-1378005066

-- Window management
opt.splitbelow = true -- force all horizontal splits to go below current window
opt.splitright = true -- force all vertical splits to go to the right of current window
opt.equalalways = true -- always equalize window sizes
opt.splitkeep = "screen"

-- Cursor behavior
opt.wrap = false -- Disable line wrapping
opt.textwidth = 120 -- the width that'll be used for wrapping (gq)
opt.whichwrap:append("<,>,[,],h,l") -- navigate to next/prev lines more naturally

-- Formatting behavior
-- Many ftplugins will override these settings; Check `:verbose setlocal formatoptions?`.
-- Duplicating them in after/ftplugin/<filetype>.lua may be necessary.
opt.formatoptions:remove("t") -- Disable text wrapping in formatting
opt.formatoptions:remove("o") -- Disable comment continuation when entering insert mode
opt.iskeyword:append("-")

opt.scrolloff = 10 -- keep lines below cursor when scrolling
opt.sidescrolloff = 15 -- keep columns after cursor when scrolling

opt.number = true -- show line numbers
opt.relativenumber = false -- nonrelative normally, relative in visual mode (see `config.autocmd`).

-- Completions
opt.completeopt = "menu,menuone,noselect" -- insert mode completion setting
opt.wildmenu = true -- visual autocomplete for command menu
opt.wildmode = "longest:full,full" -- autocomplete full on first tab, full on second tab

-- Set grep default grep command with ripgrep
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep --follow" -- --follow resolves symlinks. Not sure if...
opt.errorformat:append("%f:%l:%c%p%m")

-- Things to save in sessions
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize" }

-- folding (configured for nvim-ufo)
opt.foldcolumn = "1"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true
opt.conceallevel = 3 -- Hide * markup for bold and italic

-- treesitter folding
-- vim.wo.foldmethod = "expr"
-- vim.wo.foldexpr = "nvim_treesitter#foldexpr()"

-- diffing
opt.diffopt:append("vertical")
opt.diffopt:append("context:3")
