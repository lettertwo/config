return {
  {
    name = "laserwave.nvim",
    dev = true,
    priority = 1000,
    dir = "~/.local/share/laserwave.nvim",
    dependencies = { "rktjmp/lush.nvim", "rktjmp/shipwright.nvim" },
    opts = { dev = vim.fn.getcwd():match("laserwave.nvim") ~= nil },
    config = function(_, opts)
      require("laserwave").setup(opts)
      vim.cmd.colorscheme("laserwave")
    end,
  },
}
