return {
  {
    "nvim-treesitter/nvim-treesitter",
    keys = {
      { "<leader>ui", "<cmd>Inspect<CR>", desc = "Show Position" },
      { "<leader>uI", "<cmd>Inspect!<CR>", desc = "Inspect Position" },
      -- { "<leader>uT", "<cmd>InspectTree<CR>", desc = "Inspect TS Tree" },
      { "<leader>uQ", "<cmd>EditQuery<CR>", desc = "Edit TS Query" },
    },
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      ensure_installed = {
        "css",
        "dockerfile",
        "go",
        "gitattributes",
        "gitcommit",
        "gitignore",
        "git_rebase",
        "graphql",
        "java",
        "make",
        "rust",
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<S-CR>",
          node_incremental = "<S-CR>",
          scope_incremental = "<C-CR>",
          node_decremental = "<BS>",
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    keys = {
      {
        "gC",
        function()
          require("treesitter-context").go_to_context()
        end,
        desc = "Go to treesitter context",
      },
    },
    opts = {
      mode = "topline",
      separator = "─",
      multiline_threshold = 1,
    },
  },
}
