-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- No more accidental macros
vim.keymap.set("n", "q", "<nop>", { noremap = true })
vim.keymap.set("n", "Q", "q", { noremap = true, desc = "Record macro" })

-- no builtin keyword completions
vim.keymap.set("i", "<C-N>", "<nop>", { noremap = true })
vim.keymap.set("i", "<C-P>", "<nop>", { noremap = true })

-- better scroll up/down
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up" })

-- Move Lines: on MacOS, <A-j> emits "∆", <A-k> emits "˚"
vim.keymap.set({ "n", "i", "v" }, "∆", "<A-j>", { remap = true, desc = "Move Down" })
vim.keymap.set({ "n", "i", "v" }, "˚", "<A-k>", { remap = true, desc = "Move Down" })

-- buffers
vim.keymap.set("n", "<leader>br", "<cmd>e %<cr>", { desc = "Reopen buffer" })
vim.keymap.set("n", "<leader>bO", "<cmd>!open -R %<cr>", { desc = "Reveal file in finder" })
vim.keymap.set("n", "<leader>by", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy current file path" })

-- lazy
vim.keymap.set("n", "<leader>L", "<cmd>:LazyExtras<cr>", { desc = "Lazy Extras" })

-- mason
vim.keymap.set("n", "<leader>M", "<cmd>:Mason<cr>", { desc = "Mason" })

-- toggle options
vim.keymap.del("n", "<leader>ul")
vim.keymap.del("n", "<leader>uL")
Snacks.toggle.option("hlsearch", { name = "Highlight Search" }):map("<leader>uH")
Snacks.toggle.option("cursorline", { name = "Cursorline" }):map("<leader>uC")

-- quit
vim.keymap.set("n", "<leader>qQ", "<cmd>cq!<cr>", { desc = "Force quit (with error code)" })
vim.keymap.set("n", "<leader>qR", "<cmd>230cq<cr>", { desc = "Restart" })

-- Normal --
vim.keymap.set("n", "]q", "<cmd>cnext<CR>", { desc = "Next quickfix" })
vim.keymap.set("n", "[q", "<cmd>cprev<CR>", { desc = "Previous quickfix" })
vim.keymap.set("n", "gy", "`[v`]", { desc = "Switch to VISUAL using the last changed or yanked text" })

-- Visual --
vim.keymap.set("x", "p", '"_dP', { desc = "Paste over selection (without yanking)" })
vim.keymap.set("n", "<A-l>", ">>", { desc = "Indent right" })
vim.keymap.set("x", "<A-l>", ">gv", { desc = "Indent right" })
-- <A-l> on macos emits "¬"
vim.keymap.set("n", "¬", ">>", { desc = "Indent right" })
vim.keymap.set("x", "¬", ">gv", { desc = "Indent right" })
vim.keymap.set("n", "<A-h>", "<<", { desc = "Indent left" })
vim.keymap.set("x", "<A-h>", "<gv", { desc = "Indent left" })
-- <A-h> on macos emits "˙"
vim.keymap.set("n", "˙", "<<", { desc = "Indent left" })
vim.keymap.set("x", "˙", "<gv", { desc = "Indent left" })

-- diagnostics
vim.keymap.set("n", "]x", "]d", { desc = "Next diagnostic", remap = true })
vim.keymap.set("n", "[x", "[d", { desc = "Prev diagnostic", remap = true })
vim.keymap.set("n", "<leader>xj", "]d", { desc = "Next diagnostic", remap = true })
vim.keymap.set("n", "<leader>xk", "[d", { desc = "Prev diagnostic", remap = true })
vim.keymap.set("n", "<leader>sx", "<leader>sd", { desc = "Document diagnostics", remap = true })
vim.keymap.set("n", "<leader>sX", "<leader>sD", { desc = "Workspace diagnostics", remap = true })

-- TODO: Add some bindings for doing diff stuff, e.g.:
-- :windo diffthis -- diff buffers in all windows
-- :windo diffoff -- turn off diffing for all windows
-- :diffoff! -- alternative version of above?
-- :windo diffupdate -- update diffs for all windows

-- :[range]diffget [buf] -- same as [count]do
-- :[range]diffput [buf] -- same as [count]dp

-- :vert diffsplit %~ -- diff current buffer with previous version
-- :vert diffpatch /path/to/patch -- diff current buffer with patch from file

-- Add a way to change the diff algornthm.
-- Currently supported algorithms are:
-- myers      the default algorithm
-- minimal    spend extra time to generate the smallest possible diff
-- patience   patience diff algorithm
-- histogram  histogram diff algorithm
-- vim.opt.diffopt:append(algorithm:{text})

-- Buffer management
vim.keymap.set("n", "<leader><cr>", "<cmd>update!<CR>", { desc = "Save, if changed" })
vim.keymap.set("n", "<leader>w", "<cmd>write!<CR>", { desc = "Save" })
vim.keymap.set("n", "<leader>W", "<cmd>noautocmd write!<CR>", { desc = "Save (no autocmd)" })
vim.keymap.set("n", "<leader>bw", "<leader>w", { remap = true, desc = "Save" })
vim.keymap.set("n", "<leader>bW", "<leader>W", { remap = true, desc = "Save (no autocmd)" })
vim.keymap.set("n", "<leader>bu", "<leader><cr>", { remap = true, desc = "Save, if changed" })
vim.keymap.set("n", "<leader>ba", "<cmd>wa!<CR>", { desc = "Write all buffers" })
vim.keymap.set("n", "<leader>bC", "<cmd>%bd|e#|bd#<CR>", { desc = "Close all buffers" })

vim.keymap.set("n", "<leader>b%", "<cmd>source %<CR>", { desc = "Source current file" })
vim.keymap.set("n", "<leader>f%", "<cmd>source %<CR>", { desc = "Source current file" })

-- Tab management
vim.keymap.del("n", "<leader><tab>l")
vim.keymap.del("n", "<leader><tab>f")
vim.keymap.set("n", "<leader><tab>l", "<leader><tab>]", { remap = true, desc = "Next Tab" })
vim.keymap.set("n", "<leader><tab>h", "<leader><tab>[", { remap = true, desc = "Prev Tab" })
vim.keymap.set("n", "<leader><tab>D", "<leader><tab>o", { remap = true, desc = "Close Other Tabs" })
