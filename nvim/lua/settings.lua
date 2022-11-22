-- Set $NVIM_CONFIG_DIR to the directory containing this file.
vim.env.NVIM_CONFIG_DIR = vim.fn.stdpath("config")

-- Disable some builtins
vim.g.loaded_gzip = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1

-- Magic files
vim.opt.backup = false -- don't create backup files
vim.opt.writebackup = false -- seriously, don't create backup files
vim.opt.swapfile = false -- don't create swapfiles
vim.opt.undofile = true -- enable persistent undo

-- Default to utf-8
vim.opt.fileencoding = "utf-8"

-- Use system clipboard
vim.opt.clipboard = "unnamedplus"

-- Indents and whitespace
vim.opt.expandtab = true -- convert tabs to spaces
vim.opt.tabstop = 2 -- insert 2 spaces for a tab
vim.opt.smartindent = true -- autoindent more smartlier
vim.opt.shiftwidth = 2 -- number of spaces used in autoindent

-- Search behaviors
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Allow mouse interactivity
vim.opt.mouse = "a"

-- colorscheme
vim.g.colors_name = "laserwave"
vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.cmd([[ colorscheme laserwave ]])

-- UI settings
-- vim.opt.pumheight = 10 -- reasonable popup menu height
-- vim.opt.cmdheight = 1 -- more command line space
vim.opt.showmode = false -- hide the mode label (e.g., INSERT)
vim.opt.showtabline = 0 -- never show tabline
vim.opt.cursorline = true -- highlight the current line
vim.opt.laststatus = 3 -- always show only one statusline
vim.opt.showcmd = false -- hide display of last command
vim.opt.ruler = false -- hide display of cursor location
vim.opt.signcolumn = "yes" -- always show the sign column
vim.opt.guifont = "monospace:h14" -- use the configured monospace font
vim.opt.timeoutlen = 250 -- gotta type faster
vim.opt.updatetime = 300 -- tigger CursorHold autocmds faster
vim.opt.fillchars.eob = " " -- hide squiggles at the end of a buffer
vim.opt.colorcolumn:append("+1") -- color column at textwidth so I know when my line's too long
vim.opt.shortmess:append("c") -- hide messaging about completions

-- Window management
vim.opt.splitbelow = true -- force all horizontal splits to go below current window
vim.opt.splitright = true -- force all vertical splits to go to the right of current window
vim.opt.equalalways = true -- always equalize window sizes

-- Cursor behavior
vim.opt.wrap = false -- Disable line wrapping
vim.opt.textwidth = 120 -- the width that'll be used for wrapping (gq)
vim.opt.whichwrap:append("<,>,[,],h,l") -- navigate to next/prev lines more naturally

-- Formatting behavior
-- Many ftplugins will override these settings; Check `:verbose setlocal formatoptions?`.
-- Duplicating them in after/ftplugin/<filetype>.lua may be necessary.
vim.opt.formatoptions:remove("t") -- Disable text wrapping in formatting
vim.opt.formatoptions:remove("o") -- Disable comment continuation when entering insert mode
vim.opt.iskeyword:append("-")

vim.opt.scrolloff = 10 -- keep lines below cursor when scrolling
vim.opt.sidescrolloff = 15 -- keep columns after cursor when scrolling

vim.opt.number = true -- show line numbers
vim.opt.relativenumber = true -- relative normally, nonrelative in insert mode (see `config.autocommands`).

-- Completions
vim.opt.completeopt = { "menuone", "noselect", "noinsert" } -- insert mode completion setting
vim.opt.wildmenu = true -- visual autocomplete for command menu
vim.opt.wildmode = "longest:full,full" -- autocomplete full on first tab, full on second tab

-- Set grep default grep command with ripgrep
vim.opt.grepprg = "rg --vimgrep --follow"
vim.opt.errorformat:append("%f:%l:%c%p%m")

-- Things to save in sessions
vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,terminal,winpos,winsize"

-- folding
vim.opt.foldcolumn = "1"
vim.opt.foldlevelstart = 99
-- treesitter folding
vim.wo.foldmethod = "expr"
vim.wo.foldexpr = "nvim_treesitter#foldexpr()"

-- diffing
vim.opt.diffopt:append("vertical")
vim.opt.diffopt:append("context:3")
