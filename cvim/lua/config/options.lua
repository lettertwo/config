local opt = vim.opt

-- only set clipboard if not in ssh
-- see :h clipboard-osc52
opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus"

-- Magic files
opt.backup = false -- don't create backup files
opt.writebackup = false -- seriously, don't create backup files
opt.swapfile = false -- don't create swapfiles
opt.undofile = true -- enable persistent undo
opt.autowrite = true -- enable auto write
opt.confirm = true -- confirm to save changes before exiting modified buffer
opt.hidden = true -- Enable modified buffers in background

-- Set shada file per project/session
-- from `:h shada`:
-- > The ShaDa file is used to store:
-- > - The command line history.
-- > - The search string history.
-- > - The input-line history.
-- > - Contents of non-empty registers.
-- > - Marks for several files.
-- > - File marks, pointing to locations in files.
-- > - Last search/substitute pattern (for 'n' and '&').
-- > - The buffer list.
-- > - Global variables.
opt.exrc = true -- Enables project-local configuration. See `:h exrc` for more details.
opt.secure = true -- Require trust to execute exrc files. See `:h secure` for more details.
opt.shadafile = Config.get_session_shadafile()
-- ' - Maximum number of previously edited files for which the marks are remembered.
-- < - Maximum number of lines saved for each register.
-- s - Maximum size of an item contents in KiB.
-- : - Maximum number of items saved in the command line history.
-- / - Maximum number of items saved in the search history.
-- @ - Maximum number of items saved in the input-line history.
-- h - Disable the effect of 'hlsearch' when loading the shada file.
opt.shada = "'100,<50,s10,:1000,/100,@100,h"

opt.sessionoptions = {
  "buffers",
  "curdir",
  "tabpages",
  "winsize",
  "help",
  "globals",
  "skiprtp",
  "folds",
}

opt.timeoutlen = vim.g.vscode and 1000 or 300 -- Lower than default (1000) to quickly trigger which-key
opt.undolevels = 10000
opt.updatetime = 200 -- Save swap file and trigger CursorHold

opt.mouse = "a" -- Enable mouse mode
opt.mousescroll = "ver:1,hor:1" -- Customize mouse scroll

opt.textwidth = 120 -- the width that'll be used for wrapping (gq)
opt.linebreak = true -- Wrap lines at convenient points
opt.wrap = false -- Disable line wrap
opt.breakindent = true -- Indent wrapped lines to match line start
opt.breakindentopt = "list:-1" -- Add padding for lists (if 'wrap' is set)

-- Indentation settings
opt.autoindent = true -- Use auto indent
opt.expandtab = true -- Use spaces instead of tabs
opt.shiftround = true -- Round indent
opt.shiftwidth = 2 -- Size of an indent
opt.smartindent = true -- Insert indents automatically
opt.tabstop = 2 -- Number of spaces tabs count for

-- Formatting behavior
-- r - Automatically insert the current comment leader after hitting <Enter> in Insert mode.
-- q - Allow formatting of comments with "gq".
-- n - When formatting text, recognize numbered lists.
-- l - Long lines are not broken in insert mode.
-- 1 - Don't break a line after a one-letter word.
-- j - Where it makes sense, remove a comment leader when joining lines.
--
-- Many ftplugins will override these settings; Check `:verbose setlocal formatoptions?`.
-- Duplicating them in after/ftplugin/<filetype>.lua may be necessary.
-- o - Automatically insert the current comment leader after hitting 'o' or 'O' in Normal mode.
-- t - Auto-wrap text using 'textwidth'
-- c - Auto-wrap comments using 'textwidth', inserting the current comment
opt.formatoptions = "rqnl1j" -- Improve comment editing

-- Pattern for a start of numbered list (used in `gw`). This reads as
-- "Start of list item is: at least one special character (digit, -, +, *)
-- possibly followed by punctuation (. or `)`) followed by at least one space".
opt.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

-- Note that iskeyword is buffer-local
-- (default "@,48-57,_,192-255")
opt.iskeyword:append("-") -- add dash to iskeyword for motion commands

opt.spelloptions = "camel" -- Treat camelCase word parts as separate words

opt.diffopt = {
  "internal", -- default
  "filler", -- default
  "closeoff", -- default
  "indent-heuristic", --default
  "inline:char", -- default
  "vertical", -- Start diff mode with vertical split
  -- Use a context of {n} lines between a change
  -- and a fold that contains unchanged lines.
  "context:12",
  -- Use the histogram algorithm for the first stage diff.
  "algorithm:histogram",
  -- When the total number of lines in a hunk exceeds {n},
  -- the second stage diff will not be performed as
  -- very large hunks can cause noticeable lag.
  "linematch:200",
}

-- A more intuitive visual block mode.
opt.virtualedit = "block" -- Allow going past end of line in blockwise mode

-- search/replace settings
opt.inccommand = "nosplit" -- preview incremental substitute
opt.incsearch = true -- Show search matches while typing
opt.ignorecase = true -- Ignore case
opt.smartcase = true -- Don't ignore case with capitals
opt.infercase = true -- Infer case in built-in completion
