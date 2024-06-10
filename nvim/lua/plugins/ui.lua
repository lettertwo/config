local filetypes = require("config").filetypes

return {
  -- icons
  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "rachartier/tiny-devicons-auto-colors.nvim", lazy = true, config = true },

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

  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    opts = {
      animate = {
        enabled = false,
      },
      left = {
        {
          title = "NvimTree",
          ft = "NvimTree",
          size = { height = 0.5 },
        },
      },
      bottom = {
        {
          ft = "toggleterm",
          size = { height = 0.4 },
          -- exclude floating windows
          filter = function(buf, win)
            return vim.api.nvim_win_get_config(win).relative == ""
          end,
        },
        "Trouble",
        { ft = "qf", title = "QuickFix" },
        {
          ft = "help",
          size = { height = 20 },
          -- only show help buffers
          filter = function(buf)
            return vim.bo[buf].buftype == "help"
          end,
        },
      },
      -- Refer to my configuration here https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/extras/edgy.lua
      right = {
        {
          title = "CopilotChat.nvim", -- Title of the window
          ft = "copilot-chat", -- This is custom file type from CopilotChat.nvim
          size = { width = 0.4 }, -- Width of the window
        },
      },
      top = {},
    },
  },
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    cmd = { "SatelliteDisable", "SatelliteEnable", "SatelliteRefresh" },
    opts = {
      current_only = false,
      winblend = 50,
      excluded_filetypes = filetypes.ui,
      handlers = {
        cursor = {
          enable = true,
          -- Supports any number of symbols
          symbols = { "⎺", "⎻", "⎼", "⎽" },
          -- symbols = { '⎻', '⎼' }
          -- Highlights:
          -- - SatelliteCursor (default links to NonText
        },
        search = {
          enable = true,
          -- Highlights:
          -- - SatelliteSearch (default links to Search)
          -- - SatelliteSearchCurrent (default links to SearchCurrent)
        },
        diagnostic = {
          enable = true,
          signs = { "-", "=", "≡" },
          min_severity = vim.diagnostic.severity.HINT,
          -- Highlights:
          -- - SatelliteDiagnosticError (default links to DiagnosticError)
          -- - SatelliteDiagnosticWarn (default links to DiagnosticWarn)
          -- - SatelliteDiagnosticInfo (default links to DiagnosticInfo)
          -- - SatelliteDiagnosticHint (default links to DiagnosticHint)
        },
        gitsigns = {
          enable = true,
          signs = { -- can only be a single character (multibyte is okay)
            add = "│",
            change = "│",
            delete = "-",
          },
          -- Highlights:
          -- SatelliteGitSignsAdd (default links to GitSignsAdd)
          -- SatelliteGitSignsChange (default links to GitSignsChange)
          -- SatelliteGitSignsDelete (default links to GitSignsDelete)
        },
        marks = {
          enable = true,
          show_builtins = false, -- shows the builtin marks like [ ] < >
          key = "m",
          -- Highlights:
          -- SatelliteMark (default links to Normal)
        },
        quickfix = {
          signs = { "-", "=", "≡" },
          -- Highlights:
          -- SatelliteQuickfix (default links to WarningMsg)
        },
      },
    },
  },
  {
    "mrjones2014/smart-splits.nvim",
    event = "VeryLazy",
    build = "./kitty/install-kittens.bash",
    opts = {
      at_edge = "stop", -- 'wrap' | 'split' | 'stop'
    },
    -- stylua: ignore start
    keys = {
      -- resizing splits
      { "<C-S-h>", function() require("smart-splits").resize_left() end, desc = "Resize window left" },
      { "<C-S-l>", function() require("smart-splits").resize_right() end, desc = "Resize window right" },
      { "<C-S-j>", function() require("smart-splits").resize_down() end, desc = "Resize window down" },
      { "<C-S-k>", function() require("smart-splits").resize_up() end, desc = "Resize window up" },
      -- moving between splits
      { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Go to the left window" },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Go to the down window"},
      { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Go to the up window" },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Go to the right window" },
      -- swapping buffers between windows
      { "<C-w>xh", function() require("smart-splits").swap_buf_left() end, desc = "swap left" },
      { "<C-w>xj", function() require("smart-splits").swap_buf_down() end, desc = "swap down" },
      { "<C-w>xk", function() require("smart-splits").swap_buf_up() end, desc = "swap up" },
      { "<C-w>xl", function() require("smart-splits").swap_buf_right() end, desc = "swap right" },
      { "<C-w>R", function() require("smart-splits").start_resize_mode() end, desc = "Enter window resize mode" },


      { "<C-w>H", "<C-S-h>", remap = true, desc = "Resize window left" },
      { "<C-w>L", "<C-S-l>", remap = true, desc = "Resize window right" },
      { "<C-w>J", "<C-S-j>", remap = true, desc = "Resize window down" },
      { "<C-w>K", "<C-S-k>", remap = true, desc = "Resize window up" },
      { "<C-w>h", "<C-h>", remap = true, desc = "Go to the left window" },
      { "<C-w>j", "<C-j>", remap = true, desc = "Go to the down window"},
      { "<C-w>k", "<C-k>", remap = true, desc = "Go to the up window" },
      { "<C-w>l", "<C-l>", remap = true, desc = "Go to the right window" },
      { "<C-w>xx", "<C-w><C-x>", remap = true, desc = "swap current with next" },
      { "<C-w><Tab>", "<c-w>T", remap = true, desc = "break out into new tab" },
    },
    -- stylua: ignore end
  },
}
