return {
  {
    "akinsho/toggleterm.nvim",
    cmd = "ToggleTerm",
    keys = {
      { "\\", "<cmd>ToggleTerm<cr>", desc = "Floating terminal" },
      { "<leader>\\", "<cmd>ToggleTerm dir=%:p:h<cr>", desc = "Floating terminal at file" },
    },
    opts = {
      autochdir = true,
      direction = "float",
      shade_filetypes = {},
      hide_numbers = true,
      insert_mappings = true,
      terminal_mappings = true,
      start_in_insert = true,
      close_on_exit = true,
      persist_mode = true,
      persist_size = true,
      auto_scroll = true,
      -- shade_terminals = true,
      shell = vim.o.shell,
      -- shading_factor = 2,
      float_opts = {
        border = "curved",
      },
      highlights = {
        Float = { link = "Float" },
        FloatTitle = { link = "FloatTitle" },
        FloatBorder = { link = "FloatBorder" },
        NormalFloat = { link = "NormalFloat" },
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*toggleterm#*",
        callback = function()
          vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], { buffer = 0 })
          vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], { buffer = 0 })
          vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], { buffer = 0 })
          vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], { buffer = 0 })
          vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], { buffer = 0 })
          vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], { buffer = 0 })
        end,
      })
    end,
  },
}
