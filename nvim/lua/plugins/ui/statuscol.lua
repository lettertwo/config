return {
  {
    "folke/snacks.nvim",
    optional = true,
    opts = {
      ---@module "snacks"
      ---@type snacks.statuscolumn.Config
      statuscolumn = {
        left = { "sign", "mark" }, -- priority of signs on the left (high to low)
        right = { "fold", "git" }, -- priority of signs on the right (high to low)
      },
    },
  },
}
