return {
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPre",
    config = true,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "RRethy/nvim-treesitter-textsubjects",
      "RRethy/nvim-treesitter-endwise",
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
      local parsers = require("nvim-treesitter.parsers")
      -- Associate the flowtype filetypes with the typescript parser.
      parsers.filetype_to_parsername.flowtype = "typescript"
      parsers.filetype_to_parsername.flowtypereact = "tsx"

      require("nvim-treesitter.configs").setup({
        sync_install = false,
        auto_install = false,
        ensure_installed = {
          "bash",
          "c",
          "css",
          "dockerfile",
          "go",
          "graphql",
          "html",
          "java",
          "javascript",
          "jsdoc",
          "json",
          "json5",
          "lua",
          "make",
          "markdown",
          "python",
          "regex",
          "rust",
          "toml",
          "tsx",
          "typescript",
          "vim",
          "yaml",
        },
        ignore_install = { "haskell" },
        highlight = {
          enable = true, -- false will disable the whole extension
          additional_vim_regex_highlighting = false,
        },
        matchup = { enable = true },
        autopairs = { enable = true },
        indent = { enable = true },
        endwise = { enable = true },
        context_commentstring = { enable = true, enable_autocmd = false },
        textobjects = {
          move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
              ["]f"] = "@function.outer",
              ["]]"] = "@class.outer",
            },
            goto_next_end = {
              ["]F"] = "@function.outer",
              ["]["] = "@class.outer",
            },
            goto_previous_start = {
              ["[f"] = "@function.outer",
              ["[["] = "@class.outer",
            },
            goto_previous_end = {
              ["[F"] = "@function.outer",
              ["[]"] = "@class.outer",
            },
          },
          select = {
            enable = true,
            lookahead = true,
            include_surrounding_whitespace = true,
            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
        },
        textsubjects = {
          enable = true,
          prev_selection = "<S-CR>", -- (Optional) keymap to select the previous selection
          keymaps = {
            ["<cr>"] = "textsubjects-smart",
          },
        },
      })
    end,
  }
}
