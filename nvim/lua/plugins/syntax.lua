local Util = require("util")
local filetypes = require("config").filetypes

return {
  -- references
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    opts = {
      filetypes_denylist = filetypes.ui,
      delay = 100,
    },
    config = function(_, opts)
      require("illuminate").configure(opts)
    end,
    -- stylua: ignore
    keys = {
      { "]]", function() require("illuminate").goto_next_reference(false) end, desc = "Next Reference", },
      { "[[", function() require("illuminate").goto_prev_reference(false) end, desc = "Prev Reference" },
    },
  },

  -- indentation detection
  {
    "Darazaki/indent-o-matic",
    event = "BufReadPre",
    cmd = { "IndentOMatic" },
    opts = {
      standard_widths = { 2, 4 },
    },
  },

  -- comments
  {
    "echasnovski/mini.comment",
    event = "BufReadPost",
    config = function(_, opts)
      if Util.has("nvim-ts-context-commentstring") then
        opts.options = vim.tbl_extend("force", opts.options or {}, {
          custom_commentstring = function()
            return require("ts_context_commentstring").calculate_commentstring() or vim.bo.commentstring
          end,
        })
      end

      require("mini.comment").setup(opts)
    end,
  },

  -- surround
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {
      custom_surroundings = {
        -- Invert the balanced bracket behaviors.
        -- Open inserts without space, close inserts with space.
        ["("] = { output = { left = "(", right = ")" } },
        [")"] = { output = { left = "( ", right = " )" } },
        ["{"] = { output = { left = "{", right = "}" } },
        ["}"] = { output = { left = "{ ", right = " }" } },
        ["["] = { output = { left = "[", right = "]" } },
        ["]"] = { output = { left = "[ ", right = " ]" } },
        ["<"] = { output = { left = "<", right = ">" } },
        [">"] = { output = { left = "< ", right = " >" } },
      },
      mappings = {
        add = "gs", -- Add surrounding in Normal and Visual modes
        delete = "ds", -- Delete surrounding
        replace = "cs", -- Replace surrounding

        find = "", -- Find surrounding (to the right)
        find_left = "", -- Find surrounding (to the left)
        highlight = "", -- Highlight surrounding
        suffix_last = "", -- Suffix to search with "prev" method
        suffix_next = "", -- Suffix to search with "next" method
        update_n_lines = "", -- Update `n_lines`
      },
      n_lines = 20,
      search_method = "cover_or_next",
      respect_selection_type = true,
    },
    config = function(_, opts)
      require("mini.surround").setup(opts)

      -- Remap adding surrounding to Visual mode selection
      -- vim.keymap.del("x", "gs")
      vim.keymap.set("x", "S", "gs", { desc = "Add surrounding to selection", remap = true })

      -- Make special mapping for "add surrounding for line"
      vim.keymap.set("n", "gss", "gs_", { desc = "Add surrounding to line", remap = true })

      -- Convenience for quickly surrounding with () or {}
      vim.keymap.set("x", "(", "gs(", { desc = "Add surrounding () to selection", remap = true })
      vim.keymap.set("x", ")", "gs)", { desc = "Add surrounding () to selection", remap = true })
      vim.keymap.set("x", "{", "gs{", { desc = "Add surrounding {} to selection", remap = true })
      vim.keymap.set("x", "}", "gs}", { desc = "Add surrounding {} to selection", remap = true })
    end,
  },

  -- todo comments
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = "BufReadPost",
    opts = {
      -- highlighting for rust todo/unimplemented macros:
      -- From https://github.com/folke/todo-comments.nvim/issues/186#issuecomment-1592342384
      keywords = {
        TODO = { alt = { "todo", "unimplemented" } },
      },
      highlight = {
        pattern = {
          [[.*<(KEYWORDS)\s*:]],
          [[.*<(KEYWORDS)\s*!\(]],
        },
        comments_only = false,
      },
      search = {
        pattern = [[\b(KEYWORDS)(:|!\()]],
      },
    },
    -- stylua: ignore
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous todo comment" },
      { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "Todo" },
      { "<leader>st", "<cmd>TodoTelescope<cr>", desc = "Todo" },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    version = false, -- last release is way too old and doesn't work on Windows
    build = function()
      if #vim.api.nvim_list_uis() then
        vim.cmd([[ TSUpdate ]])
      end
    end,
    event = "BufReadPost",
    cmd = { "TSUpdateSync" },
    dependencies = {
      "RRethy/nvim-treesitter-endwise",
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    keys = {
      { "<leader>ui", "<cmd>Inspect<CR>", desc = "Show Position" },
      { "<leader>uI", "<cmd>Inspect!<CR>", desc = "Inspect Position" },
      { "<leader>uT", "<cmd>InspectTree<CR>", desc = "Inspect TS Tree" },
      { "<leader>uQ", "<cmd>EditQuery<CR>", desc = "Edit TS Query" },
    },
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      highlight = {
        enable = true, -- false will disable the whole extension
        additional_vim_regex_highlighting = { "markdown" },
      },
      endwise = { enable = true },
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
        "vimdoc",
        "yaml",
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
    init = function()
      -- Skip backwards compatibility check
      -- (see https://github.com/JoosepAlviste/nvim-ts-context-commentstring#getting-started)
      vim.g.skip_ts_context_commentstring_module = true
    end,
    ---@param opts TSConfig
    config = function(_, opts)
      local parsers = require("nvim-treesitter.parsers")
      -- Associate the flowtype filetypes with the typescript parser.
      vim.treesitter.language.register("tsx", "flowtypereact")
      vim.treesitter.language.register("tsx", "flowtype")

      require("nvim-treesitter.configs").setup(opts)
      ---@diagnostic disable-next-line: missing-fields
      require("ts_context_commentstring").setup({ enable_autocmd = false })
    end,
  },

  -- auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      disable_filetype = filetypes.ui,
      ignored_next_char = [=[[%w%%%'%[%(%{%"%.%`%$]]=],
      keys = "asdfghjklqwertyuiopzxcvbnm",
      ts_config = {
        lua = { "string", "source", "string_content" },
        javascript = { "string", "template_string" },
      },
      fast_wrap = {
        map = "<c-w>",
        chars = { "{", "[", "(", '"', "'", "`" },
        manual_position = false,
        use_virt_lines = true,
      },
    },
  },

  -- pair matching
  {
    "theHamsta/nvim-treesitter-pairs",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      pairs = {
        enable = true,
        disable = filetypes.ui,
        highlight_pair_events = {}, -- e.g. {"CursorMoved"}, -- when to highlight the pairs, use {} to deactivate highlighting
        highlight_self = false, -- whether to highlight also the part of the pair under cursor (or only the partner)
        goto_right_end = false, -- whether to go to the end of the right partner or the beginning
        fallback_cmd_normal = "normal! %", -- What command to issue when we can't find a pair (e.g. "normal! %")
        keymaps = {
          goto_partner = "%",
          delete_balanced = "X",
        },
        delete_balanced = {
          only_on_first_char = false, -- whether to trigger balanced delete when on first character of a pair
          fallback_cmd_normal = nil, -- fallback command when no pair found, can be nil
          longest_partner = false, -- whether to delete the longest or the shortest pair when multiple found.
          -- E.g. whether to delete the angle bracket or whole tag in  <pair> </pair>
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- tags
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      autotag = {
        enable = true,
        enable_rename = true,
        enable_close = true,

        filetypes = {
          "html",
          "javascript",
          "typescript",
          "javascriptreact",
          "typescriptreact",
          "svelte",
          "vue",
          "tsx",
          "jsx",
          "rescript",
          "xml",
          "php",
          "markdown",
          "astro",
          "glimmer",
          "handlebars",
          "hbs",
        },
        skip_tags = {
          "area",
          "base",
          "br",
          "col",
          "command",
          "embed",
          "hr",
          "img",
          "slot",
          "input",
          "keygen",
          "link",
          "meta",
          "param",
          "source",
          "track",
          "wbr",
          "menuitem",
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- split/join
  {
    "Wansmer/treesj",
    cmd = { "TSJToggle", "TSJToggleRecursive" },
    keys = {
      { "<leader>j", "<cmd>TSJToggle<CR>", mode = { "n", "x" }, desc = "Toggle split/join" },
      { "<leader>J", "<cmd>TSJToggleRecursive<CR>", mode = { "n", "x" }, desc = "Toggle split/join" },
    },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      use_default_keymaps = false,
    },
    config = function(_, opts)
      local treesj = require("treesj")
      treesj.setup(opts)

      vim.api.nvim_create_user_command("TSJToggleRecursive", function()
        return treesj.toggle({ split = { recursive = true } })
      end, { desc = "Toggle split/join recursively" })
    end,
  },

  -- better text-objects
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
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
      -- from https://github.com/LazyVim/LazyVim/blob/b1b5b46/lua/lazyvim/plugins/coding.lua#L181m
      -- register all text objects with which-key
      if require("util").has("which-key.nvim") then
        ---@type table<string, string|table>
        local i = {
          [" "] = "Whitespace",
          ['"'] = 'Balanced "',
          ["'"] = "Balanced '",
          ["`"] = "Balanced `",
          ["("] = "Balanced (",
          [")"] = "Balanced ) including white-space",
          [">"] = "Balanced > including white-space",
          ["<lt>"] = "Balanced <",
          ["]"] = "Balanced ] including white-space",
          ["["] = "Balanced [",
          ["}"] = "Balanced } including white-space",
          ["{"] = "Balanced {",
          ["?"] = "User Prompt",
          _ = "Underscore",
          a = "Argument",
          b = "Balanced ), ], }",
          c = "Class",
          f = "Function",
          o = "Block, conditional, loop",
          q = "Quote `, \", '",
          t = "Tag",
        }
        local a = vim.deepcopy(i)
        for k, v in pairs(a) do
          a[k] = v:gsub(" including.*", "")
        end

        local ic = vim.deepcopy(i)
        local ac = vim.deepcopy(a)
        for key, name in pairs({ n = "Next", l = "Last" }) do
          i[key] = vim.tbl_extend("force", { name = "Inside " .. name .. " textobject" }, ic)
          a[key] = vim.tbl_extend("force", { name = "Around " .. name .. " textobject" }, ac)
        end
        require("which-key").register({
          mode = { "o", "x" },
          i = i,
          a = a,
        })
      end
    end,
  },

  -- markdown preview
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    keys = {
      -- TODO: make this buffer-specific, and based on ft
      { "gM", "<cmd>MarkdownPreviewToggle<CR>", desc = "Markdown preview" },
    },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    -- init = function() end,
  },
}
