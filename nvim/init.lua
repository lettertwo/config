local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("config.options")

require("lazy").setup("plugins", {
  dev = {
    path = "~/.local/share/"
  },
  install = {
    colorscheme = { "laserwave", "habamax" }
  },
  ui = {
    border = "rounded"
  },
  checker = {
    enabled = true,
  },
})

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    require("config.autocmd")
    require("config.keymap")
  end,
})
