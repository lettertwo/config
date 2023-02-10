return {
  -- references
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    opts = { delay = 200 },
    config = function(_, opts)
      require("illuminate").configure(opts)
    end,
    -- stylua: ignore
    keys = {
      { "]]", function() require("illuminate").goto_next_reference(false) end, desc = "Next Reference", },
      { "[[", function() require("illuminate").goto_prev_reference(false) end, desc = "Prev Reference" },
    },
  },

  -- comments
  {
    "echasnovski/mini.comment",
    event = "VeryLazy",
    opts = {
      hooks = {
        pre = function()
          -- from https://github.com/JoosepAlviste/nvim-ts-context-commentstring#minicomment
          require("ts_context_commentstring.internal").update_commentstring({})
        end,
      },
    },
    config = function(_, opts)
      require("mini.comment").setup(opts)
    end,
  },

  -- surround
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "gs", -- Add surrounding in Normal and Visual modes
        delete = "ds", -- Delete surrounding
        replace = "cs", -- Replace surrounding

        find = "", -- Find surrounding kto the rightk
        find_left = "", -- Find surrounding (to the left)
        highlight = "", -- Highlight surrounding
        suffix_last = "l", -- Suffix to search with "prev" method
        suffix_next = "n", -- Suffix to search with "next" method
        update_n_lines = "", -- Update `n_lines`
      },
      n_lines = 20,
      search_method = "cover_or_next",
    },
    config = function(_, opts)
      require("mini.surround").setup(opts)

      -- Remap adding surrounding to Visual mode selection
      vim.api.nvim_del_keymap("x", "gs")
      vim.api.nvim_set_keymap("x", "S", [[:<C-u>lua MiniSurround.add("visual")<CR>]], { noremap = true })

      -- Make special mapping for "add surrounding for line"
      vim.api.nvim_set_keymap("n", "gss", "gs_", { desc = "Add surrounding to line", noremap = false })
    end,
  },

  -- todo comments
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = "BufReadPost",
    config = true,
    -- stylua: ignore
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous todo comment" },
      { "<leader>xT", "<cmd>TodoTrouble<cr>", desc = "Todo" },
      { "<leader>sT", "<cmd>TodoTelescope<cr>", desc = "Todo" },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    version = false, -- last release is way too old and doesn't work on Windows
    build = ":TSUpdate",
    event = "BufReadPost",
    dependencies = {
      "RRethy/nvim-treesitter-endwise",
      "JoosepAlviste/nvim-ts-context-commentstring",
      "nvim-treesitter/playground",
    },
    keys = {
      { "<c-space>", desc = "Increment selection" },
      { "<bs>", desc = "Shrink selection", mode = "x" },
    },
    ---@type TSConfig
    opts = {
      highlight = {
        enable = true, -- false will disable the whole extension
        additional_vim_regex_highlighting = false,
      },
      matchup = { enable = true },
      autopairs = { enable = true },
      endwise = { enable = true },
      indent = { enable = false },
      illuminate = { enable = false },
      context_commentstring = { enable = true, enable_autocmd = false },
      ensure_installed = {
        "bash",
        "c",
        "css",
        "diff",
        "dockerfile",
        "go",
        "gitattributes",
        "gitcommit",
        "gitignore",
        "git_rebase",
        "graphql",
        "help",
        "html",
        "java",
        "javascript",
        "jsdoc",
        "json",
        "json5",
        "jsonc",
        "lua",
        "make",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "rust",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "yaml",
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = "<nop>",
          node_decremental = "<bs>",
        },
      },
      playground = {
        enable = true,
        disable = {},
        updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
        persist_queries = false, -- Whether the query persists across vim sessions
        keybindings = {
          toggle_query_editor = "o",
          toggle_hl_groups = "i",
          toggle_injected_languages = "t",
          toggle_anonymous_nodes = "a",
          toggle_language_display = "I",
          focus_language = "f",
          unfocus_language = "F",
          update = "R",
          goto_node = "<cr>",
          show_help = "?",
        },
      },
    },
    ---@param opts TSConfig
    config = function(_, opts)
      local parsers = require("nvim-treesitter.parsers")
      -- Associate the flowtype filetypes with the typescript parser.
      parsers.filetype_to_parsername.flowtype = "typescript"
      parsers.filetype_to_parsername.flowtypereact = "tsx"

      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- better text-objects
  {
    "echasnovski/mini.ai",
    keys = {
      { "a", mode = { "x", "o" } },
      { "i", mode = { "x", "o" } },
    },
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter-textobjects",
        init = function()
          -- no need to load the plugin, since we only need its queries
          require("lazy.core.loader").disable_rtp_plugin("nvim-treesitter-textobjects")
        end,
      },
    },
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }, {}),
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }, {}),
        },
      }
    end,
    config = function(_, opts)
      local ai = require("mini.ai")
      ai.setup(opts)
    end,
  },
}
