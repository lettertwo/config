-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

if vim.env.FNM_DIR then
  vim.g.copilot_node_command = vim.fn.expand(vim.env.FNM_DIR) .. "/aliases/default/bin/node"
end

vim.g.lazyvim_picker = "snacks"

-- disable copilot cmp/blink source
vim.g.ai_cmp = false

vim.g.snacks_animate = false

vim.g.pager = vim.env.KITTY_SCROLLBACK_NVIM == "true"

-- Use blink main branch instead of cmp
-- vim.g.lazyvim_blink_main = true

local opt = vim.opt

-- Magic files
opt.backup = false -- don't create backup files
opt.writebackup = false -- seriously, don't create backup files
opt.swapfile = false -- don't create swapfiles
opt.undofile = true -- enable persistent undo
opt.autowrite = true -- enable auto write
opt.confirm = true -- confirm to save changes before exiting modified buffer
opt.hidden = true -- Enable modified buffers in background

opt.winblend = 0
opt.pumblend = 0

opt.listchars:remove("trail") -- don't show trailing whitespace char

opt.textwidth = 120 -- the width that'll be used for wrapping (gq)

opt.number = true -- show line numbers
opt.relativenumber = false -- nonrelative normally, relative in visual mode (see `config.autocmd`).

-- Formatting behavior
-- Many ftplugins will override these settings; Check `:verbose setlocal formatoptions?`.
-- Duplicating them in after/ftplugin/<filetype>.lua may be necessary.
opt.formatoptions:remove("t") -- Disable text wrapping in formatting
opt.formatoptions:remove("o") -- Disable comment continuation when entering insert mode

-- Note that iskeyword is buffer-local
-- (default "@,48-57,_,192-255")
opt.iskeyword:append("-") -- add dash to iskeyword for motion commands

opt.scrolloff = 10 -- keep lines below cursor when scrolling
opt.sidescrolloff = 15 -- keep columns after cursor when scrolling

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

opt.showtabline = 0

-- A more intuitive visual block mode.
opt.virtualedit = "block"

require("config.folding")
