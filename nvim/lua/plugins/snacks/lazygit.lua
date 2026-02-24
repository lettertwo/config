---@module "snacks"

return {
  {
    "folke/snacks.nvim",
    opts = {
      ---@type snacks.lazygit.Config
      lazygit = {
        configure = false,
        args = {
          "--use-config-file",
          vim.fs.normalize(vim.fn.stdpath("config") .. "/../lazygit/config.yml") .. "," .. vim.fs.normalize(
            vim.fn.stdpath("config") .. "/../lazygit/config-nvim.yml"
          ),
        },
        win = {
          style = "lazygit",
          zindex = 99,
          backdrop = false,
          width = 0,
          height = 0,
        },
      },
    },
  },
}
