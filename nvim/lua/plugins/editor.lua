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
      plugins = { spelling = true },
      window = { border = "single" },
      show_help = true,
      show_keys = true,
      key_labels = { ["<leader>"] = "<space>" },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      wk.register({
        mode = { "n", "v" },
        c = { name = "+change" },
        d = { name = "+delete" },
        g = { name = "+goto" },
        gr = { name = "+references" },
        m = { name = "+mark" },
        v = { name = "+visual" },
        y = { name = "+yank" },
        z = { name = "+fold/scroll" },
        ["]"] = { name = "+next" },
        ["["] = { name = "+prev" },
        ["!"] = { name = "+filter" },
        ["<"] = { name = "+indent/left" },
        [">"] = { name = "+indent/right" },
        ["<leader>"] = { name = "+leader" },
        ["<leader>,"] = { name = "config" },
        ["<leader>\\"] = { name = "+terminals" },
        ["<leader><tab>"] = { name = "+tabs" },
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>bp"] = { name = "+pin" },
        ["<leader>P"] = { name = "+packages" },
        ["<leader>Pl"] = { name = "+lazy" },
        ["<leader>Pm"] = { name = "+mason" },
        ["<leader>Pn"] = { name = "+npm" },
        ["<leader>Pc"] = { name = "+cargo" },
        ["<leader>c"] = { name = "+copilot" },
        ["<leader>o"] = { name = "+obsidian" },
        ["<leader>d"] = { name = "+debug" },
        ["<leader>f"] = { name = "+file/find" },
        ["<leader>g"] = { name = "+git" },
        ["<leader>l"] = { name = "+lsp" },
        ["<leader>q"] = { name = "+quit/session" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>se"] = { name = "+emoji" },
        ["<leader>sn"] = { name = "+noice" },
        ["<leader>T"] = { name = "+tests" },
        ["<leader>u"] = { name = "+ui" },
        ["<leader>x"] = { name = "+diagnostics/quickfix" },
      })
    end,
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

    -- yank(kill)-ring!
    {
      "gbprod/yanky.nvim",
      event = "BufReadPost",
      keys = {
        { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" } },
        { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" } },
        { "gp", "<Plug>(YankyGPutAfter)", mode = { "n", "x" } },
        { "gP", "<Plug>(YankyGPutBefore)", mode = { "n", "x" } },
        { "]p", "<Plug>(YankyPutIndentAfterLinewise)", mode = { "n", "x" } },
        { "[p", "<Plug>(YankyPutIndentBeforeLinewise)", mode = { "n", "x" } },
        { ">p", "<Plug>(YankyPutIndentAfterShiftRight)", mode = { "n", "x" } },
        { "<p", "<Plug>(YankyPutIndentAfterShiftLeft)", mode = { "n", "x" } },
      },
      opts = {
        textobj = {
          enabled = true,
        },
      },
    },
  },
}
