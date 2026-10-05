local map = vim.keymap.set

vim.schedule(function()
  Config.add("smart-splits-nvim/smart-splits.nvim", { version = "v3" })
  Config.add("smart-splits-nvim/backend-kitty")
  Config.add("smart-splits-nvim/backend-ghostty")

  ---@diagnostic disable-next-line: missing-fields
  require("smart-splits").setup({
    mux = {
      backend = { "smart-splits-backend-kitty", "smart-splits-backend-ghostty" },
      warn_if_unusable = false,
    },
    move = {
      at_edge = "stop", -- 'wrap' | 'split' | 'stop'
      same_row = true,
    },
  })

  -- stylua: ignore start
  -- resizing splits
  map("n", "<C-S-h>", function() require("smart-splits").resize_left() end, { desc = "Resize window left" })
  map("n", "<C-S-l>", function() require("smart-splits").resize_right() end, { desc = "Resize window right" })
  map("n", "<C-S-j>", function() require("smart-splits").resize_down() end, { desc = "Resize window down" })
  map("n", "<C-S-k>", function() require("smart-splits").resize_up() end, { desc = "Resize window up" })
  -- moving between splits
  map("n", "<C-h>", function() require("smart-splits").move_cursor_left() end, { desc = "Go to the left window" })
  map("n", "<C-j>", function() require("smart-splits").move_cursor_down() end, { desc = "Go to the down window"})
  map("n", "<C-k>", function() require("smart-splits").move_cursor_up() end, { desc = "Go to the up window" })
  map("n", "<C-l>", function() require("smart-splits").move_cursor_right() end, { desc = "Go to the right window" })
  -- swapping buffers between windows
  map("n", "<C-w>xh", function() require("smart-splits").swap_buf_left() end, { desc = "swap left" })
  map("n", "<C-w>xj", function() require("smart-splits").swap_buf_down() end, { desc = "swap down" })
  map("n", "<C-w>xk", function() require("smart-splits").swap_buf_up() end, { desc = "swap up" })
  map("n", "<C-w>xl", function() require("smart-splits").swap_buf_right() end, { desc = "swap right" })

  map("n", "<C-w>H", "<C-S-h>", { remap = true, desc = "Resize window left" })
  map("n", "<C-w>L", "<C-S-l>", { remap = true, desc = "Resize window right" })
  map("n", "<C-w>J", "<C-S-j>", { remap = true, desc = "Resize window down" })
  map("n", "<C-w>K", "<C-S-k>", { remap = true, desc = "Resize window up" })
  map("n", "<C-w>h", "<C-h>", { remap = true, desc = "Go to the left window" })
  map("n", "<C-w>j", "<C-j>", { remap = true, desc = "Go to the down window"})
  map("n", "<C-w>k", "<C-k>", { remap = true, desc = "Go to the up window" })
  map("n", "<C-w>l", "<C-l>", { remap = true, desc = "Go to the right window" })
  map("n", "<C-w>xx", "<C-w><C-x>", { remap = true, desc = "swap current with next" })
  map("n", "<C-w><Tab>", "<c-w>T", { remap = true, desc = "break out into new tab" })
  -- stylua: ignore end
end)
