---@param cmd string
---@param opts? table
---@return fun(size?: number, direction?: string): Terminal
local function toggle_cmd(cmd, opts)
  local term
  return function(size, direction)
    if term == nil then
      local Terminal = require("toggleterm.terminal").Terminal
      term = Terminal:new(vim.tbl_extend("force", opts or {
        on_open = function()
          vim.cmd("startinsert!")
        end,
        on_close = function()
          vim.cmd("startinsert!")
        end,
      }, {
        cmd = cmd,
        hidden = true, -- prevent toggling by `:ToggleTerm` and friends.
      }))
    end
    return term:toggle(size, direction)
  end
end

return {
  {
    "akinsho/toggleterm.nvim",
    event = "VeryLazy",
    cmd = "ToggleTerm",
    keys = {
      { "<leader>\\\\", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
      { "<leader>\\.", "<cmd>ToggleTerm dir=%:p:h<cr>", desc = "Toggle terminal at file" },
      { "<leader>\\g", toggle_cmd("lazygit"), desc = "Toggle lazygit" },
      { "<leader>\\n", toggle_cmd("node"), desc = "Toggle node repl" },
      -- remaps
      { "\\", "<leader>\\\\", remap = true, desc = "Toggle terminal" },
      { "<leader>gg", "<leader>\\g", remap = true, desc = "Toggle lazygit" },
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
      on_open = function()
        vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], { buffer = 0 })
        vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], { buffer = 0 })
        vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], { buffer = 0 })
        vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], { buffer = 0 })
        vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], { buffer = 0 })
        vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], { buffer = 0 })
      end,
    },
  },
}
