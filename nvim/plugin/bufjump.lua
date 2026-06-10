Config.once("BufReadPost", function()
  Config.add("kwkarlwang/bufjump.nvim")
  require("bufjump").setup({
    forward_key = "<C-i>",
    backward_key = "<C-o>",
    forward_same_buf_key = "<C-n>",
    backward_same_buf_key = "<C-p>",
  })
end)
