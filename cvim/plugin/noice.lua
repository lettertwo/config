Config.add("MunifTanjim/nui.nvim")
Config.add("folke/noice.nvim")

require("noice").setup({
  cmdline = {
    -- view = "cmdline",
    format = {
      -- execute shell command (:!)
      filter = {
        pattern = "^:%s*!",
        icon = "$",
        lang = "fish",
        opts = {
          border = {
            text = { top = " exec shell command " },
          },
        },
      },
      -- replace file content with shell command output (:%!)
      f_filter = {
        pattern = "^:%s*%%%s*!",
        icon = " $",
        lang = "fish",
        opts = { border = { text = { top = " filter file " } } },
      },
      -- replace selection with shell command output (:'<,'>!)
      v_filter = {
        pattern = "^:%s*%'<,%'>%s*!",
        icon = " $",
        lang = "fish",
        opts = { border = { text = { top = " filter selection " } } },
      },
      -- substitute (:s/, :%s/)
      substitute = {
        pattern = "^:%%?s/",
        icon = " ",
        lang = "regex",
        opts = { border = { text = { top = " sub (old/new/) " } } },
      },
      -- substitute on visual selection (:'<,'>s/)
      v_substitute = {
        pattern = "^:%s*%'<,%'>s/",
        icon = "  ",
        lang = "regex",
        opts = { border = { text = { top = " sub selection (old/new/) " } } },
      },
    },
  },
  lsp = {
    hover = { enabled = false }, -- Using a custom hover handler.
  },
  presets = {
    long_message_to_split = false, -- long messages will be sent to a split
    command_palette = true, -- position the cmdline and popupmenu together
    lsp_doc_border = true, -- add a border to hover docs and signature help
  },
  commands = {
    console = {
      view = "console",
    },
  },
})

vim.keymap.set("n", "<leader>xn", "<cmd>Noice history<cr>", { desc = "Noice history" })
vim.keymap.set("n", "<leader>xc", "<cmd>Noice console<cr>", { desc = "Noice console" })
vim.keymap.set("n", "<leader>xa", "<cmd>Noice all<cr>", { desc = "Noice all" })
vim.keymap.set("n", "<leader>xm", "<cmd>Noice last<cr>", { desc = "Last noice message" })
vim.keymap.set("n", "<leader>un", "<cmd>Noice dismiss<cr>", { desc = "Dismiss notifications" })

vim.schedule(function()
  -- Disable `:h ui2` because noice is now ready to handle the ui events.
  -- We defer this to ensure that ui2 has a chance to handle any events
  -- that occurred while noice was loading, such as the
  -- "Press any key to continue" prompt that appears when there are messages on load.
  require("vim._core.ui2").enable({ enable = false })
end)
