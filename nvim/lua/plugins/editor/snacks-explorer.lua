return {
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
  {
    "folke/snacks.nvim",

    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      explorer = {
        replace_netrw = false,
      },
    },
    keys = {
      {
        "<leader>fe",
        function()
          Snacks.explorer({ auto_close = true, cwd = LazyVim.root() })
        end,
        desc = "File Tree (root dir)",
      },
      {
        "<leader>fE",
        function()
          Snacks.explorer({
            auto_close = true,
          })
        end,
        desc = "File Tree (cwd)",
      },
      { "<leader>E", "<leader>fE", desc = "File Tree (cwd)", remap = true },
    },
  },
}
