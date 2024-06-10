require("lazy_init")

vim.o.relativenumber = true
vim.o.number = false
vim.o.mouse = "a"
vim.o.clipboard = "unnamedplus"
vim.o.virtualedit = "all"

vim.o.list = false
vim.o.foldcolumn = "0"
vim.o.signcolumn = "no"
vim.o.showtabline = 0
vim.o.scrollback = 100000
vim.o.termguicolors = true
vim.o.laststatus = 0

-- space as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- # scrollback_pager bash -c "exec nvim 63<&0 0</dev/null -u NONE -c 'map <silent> q :qa!<CR>' -c 'set
-- shell=bash scrollback=100000 termguicolors laststatus=0 clipboard+=unnamedplus' -c 'autocmd TermEnter * stopinsert' -c 'autocmd TermClose * call cursor(max([0,INPUT_LINE_NUMBER-1])+CURSOR_LINE, CURSOR_COLUMN)' -c 'terminal sed </dev/fd/63 -e \"s/'$'\x1b'']8;;file:[^\]*[\]//g\" && sleep 0.01 && printf \"'$'\x1b'']2;\"'"

vim.api.nvim_create_autocmd("TermOpen", { pattern = "*", command = "normal G" })
vim.api.nvim_create_autocmd("TermEnter", { pattern = "*", command = "stopinsert" })
vim.api.nvim_create_autocmd(
  "TermClose",
  { pattern = "*", command = "call cursor(max([0,INPUT_LINE_NUMBER-1])+CURSOR_LINE, CURSOR_COLUMN)" }
)

require("lazy").setup({
  spec = {
    { import = "plugins.colorscheme" },
    { import = "plugins.ui" },
    {
      "folke/which-key.nvim",
      opts = {
        plugins = { spelling = true },
        window = { border = "single" },
        show_help = false,
        show_keys = false,
        key_labels = { ["<leader>"] = "SPC" },
      },
      config = function(_, opts)
        local wk = require("which-key")
        wk.setup(opts)
        wk.register({
          mode = { "n", "v" },
          ["g"] = { name = "+goto" },
          ["]"] = { name = "+next" },
          ["["] = { name = "+prev" },
          ["<leader>s"] = { name = "+search" },
          ["<leader>u"] = { name = "+ui" },
        })
      end,
    },
  },
  dev = { path = "~/.local/share/" },
  install = {
    missing = true,
    colorscheme = { "laserwave", "habamax" },
  },
  ui = { border = "rounded" },
  checker = {
    enabled = false, -- automatically check for plugin updates
    notify = false, -- get a notification when updates are found
  },
  change_detection = {
    enabled = false, -- automatically check for config file changes and reload the ui
    notify = false, -- get a notification when changes are found
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

local Util = require("util")

-- better up/down
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Resize window using <ctrl> arrow keys
-- vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
-- vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
-- vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
-- vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Close floats, and clear highlights with <Esc>
vim.keymap.set("n", "<Esc>", Util.close_floats_and_clear_highlights, { desc = "Close floats, clear highlights" })

-- Clear search, diff update and redraw
-- taken from runtime/lua/_editor.lua
vim.keymap.set(
  "n",
  "<leader>ur",
  "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>",
  { desc = "Redraw / clear hlsearch / diff update" }
)

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- toggle options
vim.keymap.set("n", "<leader>us", Util.create_toggle("spell", "wo"), { desc = "Toggle Spelling" })
vim.keymap.set("n", "<leader>uw", Util.create_toggle("wrap", "wo"), { desc = "Toggle Word Wrap" })
vim.keymap.set("n", "<leader>uh", Util.create_toggle("hlsearch", "o"), { desc = "Toggle Highlight Search" })
vim.keymap.set("n", "<leader>uc", Util.create_toggle("cursorline", "wo"), { desc = "Toggle Cursorline" })

-- quit
vim.keymap.set("n", "q", "<cmd>qa!<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>q", "<cmd>qa!<cr>", { desc = "Quit" })

-- highlights under cursor
if vim.fn.has("nvim-0.9.0") == 1 then
  vim.keymap.set("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })
end
