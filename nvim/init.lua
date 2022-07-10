if require("first_run")() then
  return
end

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
-- vim.g.loaded_netrw = 1
-- vim.g.loaded_netrwPlugin = 1
-- vim.g.loaded_netrwSettings = 1

-- Magic files
vim.opt.backup = false       -- don't create backup files
vim.opt.writebackup = false  -- seriously, don't create backup files
vim.opt.swapfile = false     -- don't create swapfiles
vim.opt.undofile = true      -- enable persistent undo

-- Default to utf-8
vim.opt.fileencoding = "utf-8"

-- Use system clipboard
vim.opt.clipboard = "unnamedplus"

-- Indents and whitespace
vim.opt.expandtab = true   -- convert tabs to spaces
vim.opt.tabstop = 2        -- insert 2 spaces for a tab
vim.opt.smartindent = true -- autoindent more smartlier
vim.opt.shiftwidth = 2     -- number of spaces used in autoindent

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
vim.cmd [[ colorscheme laserwave ]]

-- UI settings
vim.opt.pumheight = 10            -- reasonable popup menu height
vim.opt.cmdheight = 2             -- more command line space
vim.opt.showmode = false          -- hide the mode label (e.g., INSERT) 
vim.opt.showtabline = 2           -- always show tabs
vim.opt.cursorline = true         -- highlight the current line
vim.opt.laststatus = 3            -- always show only one statusline
vim.opt.showcmd = false           -- hide display of last command
vim.opt.ruler = false             -- hide display of cursor location
vim.opt.signcolumn = "yes"        -- always show the sign column
vim.opt.guifont = "monospace:h14" -- use the configured monospace font
vim.opt.timeoutlen = 250          -- gotta type faster
vim.opt.updatetime = 300          -- tigger CursorHold autocmds faster
vim.opt.fillchars.eob=" "         -- hide squiggles at the end of a buffer
vim.opt.colorcolumn:append("+1")  -- color column at textwidth so I know when my line's too long
vim.opt.shortmess:append("c")     -- hide messaging about completions
vim.opt.lazyredraw = true         -- don't redraw during automations (e.g., macros)

-- Window management
vim.opt.splitbelow = true         -- force all horizontal splits to go below current window
vim.opt.splitright = true         -- force all vertical splits to go to the right of current window

-- Cursor behavior
vim.opt.wrap = false                    -- Disable line wrapping
vim.opt.formatoptions:remove("t")       -- do not automatically wrap text when typing
vim.opt.textwidth = 120                 -- the width that'll be used for wrapping (gq)
vim.opt.whichwrap:append("<,>,[,],h,l") -- navigate to next/prev lines more naturally

vim.opt.iskeyword:append("-")

vim.opt.scrolloff = 10        -- keep lines below cursor when scrolling
vim.opt.sidescrolloff = 15    -- keep columns after cursor when scrolling

vim.opt.number = true         -- show line numbers
vim.opt.relativenumber = true -- relative normally, nonrelative in insert mode (see `config.autocommands`).


-- Completions
vim.opt.completeopt = { "menu", "menuone", "noselect" } -- insert mode completion setting
vim.opt.wildmenu = true                                 -- visual autocomplete for command menu
vim.opt.wildmode = "longest:full,full"                  -- autocomplete full on first tab, full on second tab

-- Set grep default grep command with ripgrep
vim.opt.grepprg = "rg --vimgrep --follow"
vim.opt.errorformat:append("%f:%l:%c%p%m")

-- Things to save in sessions
vim.opt.sessionoptions = "buffers,curdir,folds,tabpages,winpos,winsize"

-- folding
vim.opt.foldcolumn = "1"
vim.opt.foldlevelstart = 99

-- copilot suggestions are integrated into cmp
vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true

require("autocommands")
require("plugins")

if (vim.g.CONFIG_LOADED) then
  print("Config reloaded!")
end
vim.g.CONFIG_LOADED = true
