return {
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
      { "<leader>e", false },
      {
        "<leader>fe",
        function()
          Snacks.explorer({ cwd = LazyVim.root(), layout = { layout = { width = 0.3 } } })
        end,
        desc = "File Tree (root dir)",
      },
      {
        "<leader>fE",
        function()
          Snacks.explorer({ layout = { layout = { width = 0.3 } } })
        end,
        desc = "File Tree (cwd)",
      },
      { "<leader>E", "<leader>fE", desc = "File Tree (cwd)", remap = true },
    },
  },
}
