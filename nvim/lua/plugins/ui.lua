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
    keys = {
      {
        "<leader>un",
        function()
          require("notify").dismiss({ silent = true, pending = true })
        end,
        desc = "Delete all Notifications",
      },
    },
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
    opts = {
      mode = "topline",
    },
  },

  -- indent guides for Neovim
  {
    "lukas-reineke/indent-blankline.nvim",
    event = "BufReadPost",
    opts = {
      char = "╎",
      filetype_exclude = filetypes.ui,
      show_trailing_blankline_indent = false,
      show_current_context = false,
    },
    keys = {
      { "zo", "zo<CMD>IndentBlanklineRefresh<CR>" },
      { "zO", "zO<CMD>IndentBlanklineRefresh<CR>" },
      { "zc", "zc<CMD>IndentBlanklineRefresh<CR>" },
      { "zC", "zC<CMD>IndentBlanklineRefresh<CR>" },
      { "za", "za<CMD>IndentBlanklineRefresh<CR>" },
      { "zA", "zA<CMD>IndentBlanklineRefresh<CR>" },
      { "zv", "zv<CMD>IndentBlanklineRefresh<CR>" },
      { "zx", "zx<CMD>IndentBlanklineRefresh<CR>" },
      { "zX", "zX<CMD>IndentBlanklineRefresh<CR>" },
      { "zm", "zm<CMD>IndentBlanklineRefresh<CR>" },
      { "zM", "zM<CMD>IndentBlanklineRefresh<CR>" },
      { "zr", "zr<CMD>IndentBlanklineRefresh<CR>" },
      { "zR", "zR<CMD>IndentBlanklineRefresh<CR>" },
    },
  },

  -- active indent guide and indent text objects
  {
    "echasnovski/mini.indentscope",
    version = false,
    event = "BufReadPost",
    opts = {
      symbol = "╎",
      --stylua: ignore
      draw = { delay = 0, animation = function() return 0 end },
      options = {
        border = "both",
        indent_at_cursor = true,
        try_as_border = true,
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
          view = "notify",
          filter = { event = "msg_showmode" },
        },
        {
          filter = { event = "msg_show", kind = "", find = "written" },
          opts = { skip = true },
        },
        {
          filter = { event = "msg_show", kind = "", find = "lines" },
          opts = { skip = true },
        },
        {
          filter = { event = "msg_show", kind = "", find = "line" },
          opts = { skip = true },
        },
        {
          filter = { event = "msg_show", kind = "", find = "change" },
          opts = { skip = true },
        },
      },
    },
    -- stylua: ignore
    keys = {
      { "<S-Enter>", function() require("noice").redirect(vim.fn.getcmdline()) end, mode = "c", desc = "Redirect Cmdline" },
      { "<leader>snl", function() require("noice").cmd("last") end, desc = "Noice Last Message" },
      { "<leader>snh", function() require("noice").cmd("history") end, desc = "Noice History" },
      { "<leader>sna", function() require("noice").cmd("all") end, desc = "Noice All" },
      { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll forward" },
      { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll backward"},
    },
  },
}
