return {
  {
    "mrjones2014/smart-splits.nvim",
    event = "VeryLazy",
    build = "./kitty/install-kittens.bash",
    opts = {
      at_edge = "stop", -- 'wrap' | 'split' | 'stop'
    },
    -- stylua: ignore start
    keys = {
      -- resizing splits
      { "<C-S-h>", function() require("smart-splits").resize_left() end, desc = "Resize window left" },
      { "<C-S-l>", function() require("smart-splits").resize_right() end, desc = "Resize window right" },
      { "<C-S-j>", function() require("smart-splits").resize_down() end, desc = "Resize window down" },
      { "<C-S-k>", function() require("smart-splits").resize_up() end, desc = "Resize window up" },
      -- moving between splits
      { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Go to the left window" },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Go to the down window"},
      { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Go to the up window" },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Go to the right window" },
      -- swapping buffers between windows
      { "<C-w>xh", function() require("smart-splits").swap_buf_left() end, desc = "swap left" },
      { "<C-w>xj", function() require("smart-splits").swap_buf_down() end, desc = "swap down" },
      { "<C-w>xk", function() require("smart-splits").swap_buf_up() end, desc = "swap up" },
      { "<C-w>xl", function() require("smart-splits").swap_buf_right() end, desc = "swap right" },
      { "<C-w>R", function() require("smart-splits").start_resize_mode() end, desc = "Enter window resize mode" },


      { "<C-w>H", "<C-S-h>", remap = true, desc = "Resize window left" },
      { "<C-w>L", "<C-S-l>", remap = true, desc = "Resize window right" },
      { "<C-w>J", "<C-S-j>", remap = true, desc = "Resize window down" },
      { "<C-w>K", "<C-S-k>", remap = true, desc = "Resize window up" },
      { "<C-w>h", "<C-h>", remap = true, desc = "Go to the left window" },
      { "<C-w>j", "<C-j>", remap = true, desc = "Go to the down window"},
      { "<C-w>k", "<C-k>", remap = true, desc = "Go to the up window" },
      { "<C-w>l", "<C-l>", remap = true, desc = "Go to the right window" },
      { "<C-w>xx", "<C-w><C-x>", remap = true, desc = "swap current with next" },
      { "<C-w><Tab>", "<c-w>T", remap = true, desc = "break out into new tab" },
    },
    -- stylua: ignore end
  },
}
