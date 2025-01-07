return {
  -- TODO: which-key.nvim
  -- TODO: nvim-treesitter-textobjects
  -- TODO: nvim-ts-autotag
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
      highlight = {
        additional_vim_regex_highlighting = { "markdown" },
      },
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
        "json5",
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
    ---@param opts TSConfig
    config = function(_, opts)
      -- Associate the flowtype filetypes with the typescript parser.
      vim.treesitter.language.register("tsx", "flowtypereact")
      vim.treesitter.language.register("tsx", "flowtype")
      require("nvim-treesitter.configs").setup(opts)
    end,
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
