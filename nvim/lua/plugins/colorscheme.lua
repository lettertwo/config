return {
  {
    dev = true,
    priority = 1000,
    dir = "~/.local/share/laserwave.nvim",
    name = "laserwave.nvim",
    dependencies = { "rktjmp/lush.nvim", "rktjmp/shipwright.nvim" },
    config = function()
      vim.g.colors_name = "laserwave"
      vim.opt.termguicolors = true
      vim.opt.background = "dark"
      vim.cmd([[ colorscheme laserwave ]])
    end,
  },
}
