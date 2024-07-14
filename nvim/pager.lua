require("lazy_init")
require("config.options")

vim.o.signcolumn = "no" -- never show the sign column
vim.o.foldcolumn = "0" -- hide fold column

require("lazy").setup({
  spec = {
    { import = "plugins.colorscheme" },
    { import = "plugins.ui" },
    { import = "plugins.kitty" },
    {
      "folke/which-key.nvim",
      opts = {
        preset = "modern",
        delay = 0,
        show_help = true,
        show_keys = true,
        triggers = true,
        spec = {
          mode = { "n", "v" },
          { "c", group = "change" },
          { "d", group = "delete" },
          { "g", group = "goto" },
          { "v", group = "visual" },
          { "y", group = "yank" },
          { "z", group = "fold/scroll" },
          { "]", group = "next" },
          { "[", group = "prev" },
          { "!", group = "filter" },
          { "<", group = "indent/left" },
          { ">", group = "indent/right" },
          { "<leader>", group = "leader" },
          { "<leader>u", group = "ui" },
          { "<leader>x", group = "diagnostics" },
        },
      },
    },
  },
  dev = { path = "~/.local/share" },
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

-- better up/down
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- better scroll up/down
vim.keymap.set("n", "<C-d>", "'<C-d>zz'", { expr = true, silent = true, desc = "Scroll down" })
vim.keymap.set("n", "<C-u>", "'<C-u>zz'", { expr = true, silent = true, desc = "Scroll up" })

vim.keymap.set("n", "<leader>L", "<cmd>:Lazy<cr>", { desc = "Lazy" })
vim.keymap.set("n", "q", "<cmd>qa!<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>q", "<cmd>qa!<cr>", { desc = "Quit" })
