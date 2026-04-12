local opt = vim.opt

opt.winblend = 0
opt.winborder = "rounded"
opt.winminwidth = 5 -- Minimum window width

opt.pumblend = 0
opt.pumborder = "rounded" -- Use border in popup menu
opt.pumheight = 10 -- Make popup menu smaller
opt.pummaxwidth = 100 -- Make popup menu not too wide

opt.laststatus = 3 -- global statusline
opt.cmdheight = 0 -- hide cmdline unless needed
opt.ruler = false -- Disable the default ruler
opt.showmode = false -- Dont show mode since we have a statusline
opt.signcolumn = "yes" -- Always show the signcolumn, otherwise it would shift the text each time
opt.showtabline = 0
opt.smoothscroll = true

opt.shortmess:append({ W = true, I = true, c = true, C = true })
-- opt.shortmess = "CFOSWaco" -- Disable some built-in completion messages
opt.messagesopt = {
	"wait:0",
	"history:10000",
	"progress:",
}

opt.list = true -- Show some invisible characters (tabs...
opt.listchars = {
	extends = "…",
	nbsp = "␣",
	precedes = "…",
	tab = "> ",
}

opt.fillchars = {
	foldopen = "",
	foldclose = "",
	fold = " ",
	foldsep = " ",
	diff = "╱",
	eob = " ",
}

opt.complete = ".,w,b,kspell" -- Use less sources
opt.completeopt = "menuone,noselect,fuzzy,nosort" -- Use custom behavior
opt.completetimeout = 100 -- Limit sources delay
opt.wildmode = "longest:full,full" -- Command-line completion mode

opt.cursorline = true -- Enable highlighting of the current line
opt.cursorlineopt = "screenline,number" -- Show cursor line per screen line
opt.number = true -- show line numbers
opt.relativenumber = false -- nonrelative normally, relative in visual mode (see `config.autocmd`).

opt.scrolloff = 10 -- keep lines below cursor when scrolling
opt.sidescrolloff = 15 -- keep columns after cursor when scrolling

opt.splitbelow = true -- Put new windows below current
opt.splitright = true -- Put new windows right of current
opt.splitkeep = "screen" -- Reduce scroll during window split
opt.switchbuf = "usetab" -- Use already opened buffers when switching

-- Enable `:h ui2` just to squash 'press any key to continue' prompts.
-- We'll disable this as soon as noice is ready to handle it.
-- See plugin/noice.lua for more details.
require("vim._core.ui2").enable({ enable = true })
