return {
  {
    "mikesmithgh/kitty-scrollback.nvim",
    lazy = true,
    cond = vim.g.pager,
    cmd = {
      "KittyScrollbackGenerateKittens",
      "KittyScrollbackCheckHealth",
      "KittyScrollbackGenerateCommandLineEditing",
    },
    event = { "User KittyScrollbackLaunch" },
    opts = {
      {
        callbacks = {
          after_launch = function()
            vim.keymap.set("n", "q", "<cmd>qa!<cr>", { desc = "Quit" })
          end,
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    optional = true,
    opts = {
      dashboard = {
        enabled = not vim.g.pager,
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    cond = not vim.g.pager,
  },
}
