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

-- Move Lines
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })
-- Move Lines: on MacOS, <A-j> emits "∆", <A-k> emits "˚"
map({ "n", "i", "v" }, "∆", "<A-j>", { remap = true, desc = "Move Down" })
map({ "n", "i", "v" }, "˚", "<A-k>", { remap = true, desc = "Move Down" })

-- better indenting
map("x", "<", "<gv", { desc = "Indent selection left" })
map("x", ">", ">gv", { desc = "Indent selection right" })

-- commenting
map("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Below" })
map("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Above" })

--keywordprg
map("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keywordprg" })

-- Ctrl+Enter to change the word under the cursor
map("n", "<C-CR>", "ciw", { desc = "Change word under cursor" })
map("i", "<C-CR>", "<C-o>diw", { desc = "Change next word under cursor" })

-- Add undo break-points
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

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
  vim.schedule(function()
    vim.cmd("nohlsearch | diffupdate | normal! <C-L><CR>")
  end)
  return "<esc>"
end, { expr = true, desc = "Escape and redraw" })

-- location list
map("n", "<leader>xl", function()
  local success, err = pcall(vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and vim.cmd.lclose or vim.cmd.lopen)
  if not success and err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end, { desc = "Location List" })

-- quickfix list
map("n", "<leader>xq", function()
  local success, err = pcall(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and vim.cmd.cclose or vim.cmd.copen)
  if not success and err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end, { desc = "Quickfix List" })

-- highlights under cursor
map("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })
map("n", "<leader>uI", function()
  vim.treesitter.inspect_tree()
  vim.api.nvim_input("I")
end, { desc = "Inspect Tree" })

--- incremental treesitter selection mappings (+ lsp fallback)
map({ "n", "o", "x" }, "<S-CR>", function()
  if vim.treesitter.get_parser(nil, nil, { error = false }) and pcall(require, "vim.treesitter._select") then
    require("vim.treesitter._select").select_parent(vim.v.count1)
  else
    vim.lsp.buf.selection_range(vim.v.count1)
  end
end, { desc = "Increment Selection" })

map({ "o", "x" }, "<BS>", function()
  if vim.treesitter.get_parser(nil, nil, { error = false }) and pcall(require, "vim.treesitter._select") then
    require("vim.treesitter._select").select_child(vim.v.count1)
  else
    vim.lsp.buf.selection_range(-vim.v.count1)
  end
end, { desc = "Decrement Selection" })

map("n", "<leader>P", function()
  vim.pack.update()
end, { desc = "Manage Plugins" })
