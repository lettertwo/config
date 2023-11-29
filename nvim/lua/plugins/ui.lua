local filetypes = require("config").filetypes

return {
  -- icons
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- ui components
  { "MunifTanjim/nui.nvim", lazy = true },

  -- Fade inactive windows while preserving syntax highlights.
  {
    "levouh/tint.nvim",
    event = "VeryLazy",
    opts = {
      tint = -50,
      saturation = 0.5,
      highlight_ignore_patterns = { "WinSeparator", "Status.*", "IndentBlankline*" },
    },
  },

  -- highlight undo/redo events
  { "tzachar/highlight-undo.nvim", config = true },

  -- better vim.notify
  {
    "rcarriga/nvim-notify",
    opts = {
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
    },
  },
  -- better vim.ui
  {
    "stevearc/dressing.nvim",
    lazy = true,
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.select(...)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.input(...)
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPost",
    cmds = { "TSContextToggle" },
    keys = {
      { "<leader>uC", "<cmd>TSContextToggle<cr>", desc = "Toggle TS Context" },
      {
        "gC",
        function()
          require("treesitter-context").go_to_context()
        end,
        desc = "Go to treesitter context",
      },
    },
    opts = { mode = "topline", enable = false },
  },

  -- indent guides for Neovim
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "BufReadPost",
    opts = {
      indent = { char = "┆" },
      whitespace = { remove_blankline_trail = false },
      scope = { enabled = false },
      exclude = { filetypes = filetypes.ui },
    },
  },

  -- active indent guide and indent text objects
  {
    "echasnovski/mini.indentscope",
    version = false,
    event = "BufReadPost",
    opts = {
      symbol = "┆",
      --stylua: ignore
      draw = { delay = 0, animation = function() return 0 end },
      options = {
        border = "both",
        indent_at_cursor = true,
        try_as_border = true,
      },
      mappings = {
        object_scope = "ii",
        object_scope_with_border = "ai",
        goto_top = "[i",
        goto_bottom = "]i",
      },
    },
    config = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = filetypes.ui,
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
      require("mini.indentscope").setup(opts)
    end,
  },

  -- noicer ui
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        hover = { enabled = false }, -- Using a custom hover handler. See `config.lsp`.
      },
      presets = {
        long_message_to_split = true, -- long messages will be sent to a split
        command_palette = true, -- position the cmdline and popupmenu together
        lsp_doc_border = true, -- add a border to hover docs and signature help
        inc_rename = vim.fn.exists(":IncRename"),
      },
      routes = {
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
            },
          },
          view = "mini",
        },
        {
          filter = {
            event = "lsp",
            kind = "progress",
            any = {
              { find = "Processing" },
              { find = "Diagnosing" },
            },
            cond = function(message)
              local client = vim.tbl_get(message.opts, "progress", "client")
              return client == "lua_ls" -- skip lua-ls progress
            end,
          },
          opts = { skip = true },
        },
      },
    },
    -- stylua: ignore
    keys = {
      { "<S-Enter>", function() require("noice").redirect(vim.fn.getcmdline()) end, mode = "c", desc = "Redirect Cmdline" },
      { "<leader>xn", "<cmd>Noice all<cr>", desc = "Noice" },
      { "<leader>xm", "<cmd>Noice last<cr>", desc = "Noice Last Message" },
      { "<leader>sn", "<cmd>Noice telescope<cr>", desc= "Noice messages" },
      { "<leader>un", "<cmd>Noice dismiss<cr>", desc="Dismiss notifications" },
      { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll forward" },
      { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll backward" },
    },
  },
}
