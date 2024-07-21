return {
  -- easily jump to any location and enhanced /, ?, f, t, F, T motions
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    -- stylua: ignore
    keys = {
      { "S", mode = { "o", "x" }, function() require("flash").jump() end, desc = "Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "<c-/>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  -- which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = 0,
      show_help = true,
      show_keys = true,
      spec = {
        { "c", group = "change" },
        { "d", group = "delete" },
        { "g", group = "goto" },
        { "gr", group = "references" },
        { "m", group = "mark" },
        { "v", group = "visual" },
        { "y", group = "yank" },
        { "z", group = "fold/scroll" },
        { "]", group = "next" },
        { "[", group = "prev" },
        { "!", group = "filter" },
        { "<", group = "indent/left" },
        { ">", group = "indent/right" },
        { "<leader>", group = "leader" },
        { "<leader>,", group = "config" },
        { "<leader>\\", group = "terminals" },
        { "<leader><tab>", group = "tabs" },
        { "<leader>b", group = "buffer" },
        { "<leader>bp", group = "pin" },
        { "<leader>P", group = "packages" },
        { "<leader>Pl", group = "lazy" },
        { "<leader>Pm", group = "mason" },
        { "<leader>Pn", group = "npm" },
        { "<leader>Pc", group = "cargo" },
        { "<leader>c", group = "copilot" },
        { "<leader>o", group = "obsidian" },
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "file/find" },
        { "<leader>g", group = "git" },
        { "<leader>l", group = "lsp" },
        { "<leader>q", group = "quit/session" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "task" },
        { "<leader>se", group = "emoji" },
        { "<leader>sn", group = "noice" },
        { "<leader>T", group = "tests" },
        { "<leader>u", group = "ui" },
        { "<leader>x", group = "diagnostics/quickfix" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },

  -- buffer remove
  {
    "echasnovski/mini.bufremove",
    -- stylua: ignore
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete Buffer" },
      { "<leader>bD", function() require("mini.bufremove").delete(0, true) end, desc = "Delete Buffer (Force)" },
    },
  },

  -- smarter jumplist
  {
    "kwkarlwang/bufjump.nvim",
    opts = {
      forward_key = "<C-n>",
      backward_key = "<C-p>",
      forward_same_buf_key = "<C-i>",
      backward_same_buf_key = "<C-o>",
    },
  },

  -- sticky buffers
  {
    "stevearc/stickybuf.nvim",
    event = "VeryLazy",
    cmd = { "PinBuffer", "PinBuftype", "PinFiletype", "Unpin" },
    keys = {
      { "<leader>bpb", "<cmd>PinBuffer<cr>", desc = "Pin buffer" },
      { "<leader>bpt", "<cmd>PinBuftype<cr>", desc = "Pin buffer type" },
      { "<leader>bpf", "<cmd>PinFiletype<cr>", desc = "Pin fileytype" },
      { "<leader>bpu", "<cmd>Unpin<cr>", desc = "Unpin buffer" },
    },
    opts = {
      get_auto_pin = function(buffer)
        local should_pin = require("stickybuf").should_auto_pin(buffer)
        if should_pin == nil then
          local filetype = vim.bo[buffer].filetype
          if vim.tbl_contains({ "noice" }, filetype) then
            return "filetype"
          end
        end
        return should_pin
      end,
    },
    config = function(_, opts)
      require("stickybuf").setup(opts)

      vim.api.nvim_create_autocmd("BufEnter", {
        desc = "Pin the buffer to any window that is fixed width or height",
        callback = function()
          if (vim.wo.winfixwidth or vim.wo.winfixheight) and vim.w.sticky_win == nil then
            require("stickybuf").pin()
          end
        end,
      })
    end,
  },

  -- operators, evals
  {
    "echasnovski/mini.operators",
    event = "VeryLazy",
    opts = {
      evaluate = {
        prefix = "g=",
        func = nil,
      },
      exchange = {
        prefix = "gX",
        -- Whether to reindent new text to match previous indent
        reindent_linewise = true,
      },
      multiply = {
        prefix = "gm",
        func = nil,
      },
      replace = {
        prefix = "gR",
        -- Whether to reindent new text to match previous indent
        reindent_linewise = true,
      },
      sort = {
        prefix = "gS",
        func = nil,
      },
    },
  },

  -- yank(kill)-ring!
  {
    "gbprod/yanky.nvim",
    event = "BufReadPost",
    keys = {
      { "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yank text" },
      { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put yanked text after cursor" },
      { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put yanked text before cursor" },
      { "gp", "<Plug>(YankyGPutAfter)", mode = { "n", "x" }, desc = "Put yanked text after selection" },
      { "gP", "<Plug>(YankyGPutBefore)", mode = { "n", "x" }, desc = "Put yanked text before selection" },
      { "]p", "<Plug>(YankyPutIndentAfterLinewise)", desc = "Put indented after cursor (linewise)" },
      { "[p", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "Put indented before cursor (linewise)" },
      { ">p", "<Plug>(YankyPutIndentAfterShiftRight)", desc = "Put and indent right" },
      { "<p", "<Plug>(YankyPutIndentAfterShiftLeft)", desc = "Put and indent left" },
      -- { "=p", "<Plug>(YankyPutAfterFilter)", desc = "Put after applying a filter" },
      -- { "=P", "<Plug>(YankyPutBeforeFilter)", desc = "Put before applying a filter" },
    },
    opts = {
      textobj = {
        enabled = true,
      },
    },
  },
}
