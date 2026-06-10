return {
  {
    "nvim-treesitter/nvim-treesitter",
    keys = {
      { "<leader>ui", "<cmd>Inspect<CR>", desc = "Show Position" },
      { "<leader>uI", "<cmd>Inspect!<CR>", desc = "Inspect Position" },
      -- { "<leader>uT", "<cmd>InspectTree<CR>", desc = "Inspect TS Tree" },
      { "<leader>uQ", "<cmd>EditQuery<CR>", desc = "Edit TS Query" },
      --- incremental treesitter selection mappings (+ lsp fallback)
      {
        "<S-CR>",
        mode = { "n", "o", "x" },
        function()
          if vim.treesitter.get_parser(nil, nil, { error = false }) and pcall(require, "vim.treesitter._select") then
            require("vim.treesitter._select").select_parent(vim.v.count1)
          else
            vim.lsp.buf.selection_range(vim.v.count1)
          end
        end,
        desc = "Increment Selection",
      },
      {
        "<BS>",
        mode = { "o", "x" },
        function()
          if vim.treesitter.get_parser(nil, nil, { error = false }) and pcall(require, "vim.treesitter._select") then
            require("vim.treesitter._select").select_child(vim.v.count1)
          else
            vim.lsp.buf.selection_range(-vim.v.count1)
          end
        end,
        desc = "Decrement Selection",
      },
    },
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
    },
  },
  {
    "folke/flash.nvim",
    optional = true,
    keys = {
      { "<c-space>", false }, -- Disable flash's incremental selection in favor of the treesitter + LSP above.
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
