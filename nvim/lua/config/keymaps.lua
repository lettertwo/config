local map = vim.keymap.set

-- No more accidental macros
map("n", "q", "<nop>", { noremap = true })
map("n", "Q", "q", { noremap = true, desc = "Record macro" })

-- no builtin keyword completions
map("i", "<C-N>", "<nop>", { noremap = true })
map("i", "<C-P>", "<nop>", { noremap = true })

-- quit
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })
map("n", "<leader>qQ", "<cmd>cq!<cr>", { desc = "Force quit (with error code)" })
map("n", "<leader>qR", "<cmd>restart<cr>", { desc = "Restart" })

-- better up/down
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

-- better indenting
map("x", "<", "<gv", { desc = "Indent selection left" })
map("x", ">", ">gv", { desc = "Indent selection right" })

-- buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>br", "<cmd>e %<cr>", { desc = "Reopen buffer" })
map("n", "<leader>bO", "<cmd>!open -R '%'<cr>", { desc = "Reveal file in finder" })
map("n", "<leader>b%", "<cmd>source %<CR>", { desc = "Source current file" })
map("n", "<leader>by", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy current file path" })

-- save file
map("n", "<leader><cr>", "<cmd>update!<CR>", { desc = "Save, if changed" })
map("n", "<leader>w", "<cmd>write!<CR>", { desc = "Save" })
map("n", "<leader>W", "<cmd>noautocmd write!<CR>", { desc = "Save (no autocmd)" })
map("n", "<leader>bw", "<leader>w", { remap = true, desc = "Save" })
map("n", "<leader>bW", "<leader>W", { remap = true, desc = "Save (no autocmd)" })
map("n", "<leader>bu", "<leader><cr>", { remap = true, desc = "Save, if changed" })
map("n", "<leader>ba", "<cmd>wa!<CR>", { desc = "Write all buffers" })

-- tabs
map("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last Tab" })
map("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close Other Tabs" })
map("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First Tab" })
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

-- Clear search, diff update and redraw on <esc>
map({ "i", "n", "s" }, "<esc>", function()
  if vim.fn.pumvisible() ~= 0 then
    return "<C-e>" -- Close pum without choosing, but don't exit insert mode
  else
    vim.schedule(function()
      vim.cmd("nohlsearch | diffupdate | normal! <C-L><CR>")
    end)
  end
  return "<esc>"
end, { expr = true, desc = "Escape and redraw" })

map("n", "<leader>P", function()
  vim.pack.update()
end, { desc = "Manage Plugins" })
