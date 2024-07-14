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

  -- noicer ui
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      cmdline = {
        format = {
          -- execute shell command (:!)
          filter = { pattern = "^:%s*!", icon = "$", lang = "fish" },
          -- replace file content with shell command output (:%!)
          f_filter = {
            pattern = "^:%s*%%%s*!",
            icon = " $",
            lang = "fish",
            opts = { border = { text = { top = " filter file " } } },
          },
          -- replace selection with shell command output (:'<,'>!)
          v_filter = {
            pattern = "^:%s*%'<,%'>%s*!",
            icon = " $",
            lang = "fish",
            opts = { border = { text = { top = " filter selection " } } },
          },
          -- substitute (:s/, :%s/)
          substitute = {
            pattern = "^:%%?s/",
            icon = " ",
            lang = "regex",
            opts = { border = { text = { top = " sub (old/new/) " } } },
          },
          -- substitute on visual selection (:'<,'>s/)
          v_substitute = {
            pattern = "^:%s*%'<,%'>s/",
            icon = "  ",
            lang = "regex",
            opts = { border = { text = { top = " sub selection (old/new/) " } } },
          },
        },
      },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        hover = { enabled = false }, -- Using a custom hover handler. See `config.lsp`.
      },
      presets = {
        long_message_to_split = false, -- long messages will be sent to a split
        command_palette = true, -- position the cmdline and popupmenu together
        lsp_doc_border = true, -- add a border to hover docs and signature help
        inc_rename = vim.fn.exists(":IncRename") ~= 0,
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
      { "<leader>xn", "<cmd>Noice all<cr>", desc = "Noice messages" },
      { "<leader>xm", "<cmd>Noice last<cr>", desc = "Last noice message" },
      { "<leader>un", "<cmd>Noice dismiss<cr>", desc="Dismiss notifications" },
      { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll forward" },
      { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll backward" },
    },
    config = function(_, opts)
      require("noice").setup(opts)
      if require("util").has("telescope.nvim") then
        vim.keymap.set("n", "<leader>sn", "<cmd>Noice telescope<cr>", { desc = "Noice messages" })
      end
    end,
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
        {
          title = "Symbols Outline",
          ft = "trouble",
          filter = function(buf, win)
            return vim.w[win].trouble.mode == "lsp_document_symbols"
          end,
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
        {
          ft = "noice",
          size = { height = 0.4 },
          filter = function(buf, win)
            return vim.api.nvim_win_get_config(win).relative == ""
          end,
        },
        "trouble",
        { ft = "qf", title = "QuickFix" },
        {
          ft = "help",
          size = { height = 0.4 },
          -- only show help buffers
          filter = function(buf)
            return vim.bo[buf].buftype == "help"
          end,
        },
        {
          title = "CopilotChat.nvim", -- Title of the window
          ft = "copilot-chat", -- This is custom file type from CopilotChat.nvim
          size = { height = 0.4 }, -- Width of the window
        },
      },
      right = {},
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
}
