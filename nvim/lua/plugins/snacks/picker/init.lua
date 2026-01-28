return {
  {
    "folke/snacks.nvim",
    --stylua: ignore
    keys = {
      { "<leader>f<space>", LazyVim.pick("pickers"),                      desc = "Find Pickers" },
      { "<leader>qp",       LazyVim.pick("projects"),                     desc = "Projects" },
      { "<leader>nn",       function() Snacks.picker.notifications() end, desc = "Notification History" },

      -- git
      { "<leader>gb", LazyVim.pick("git_log_line"), desc = "Git Blame Line" },
      { "<leader>gB", LazyVim.pick("git_branches"), desc = "Git Branches" },
      { "<leader>gd", LazyVim.pick("git_diff"),     desc = "Git Diff (hunks)" },
      { "<leader>go", LazyVim.pick("git_diff", { base = "origin" }), desc = "Git Diff (origin)" },
      { "<leader>gf", LazyVim.pick("git_files"),    desc = "Find Git Files" },
      { "<leader>gl", LazyVim.pick("git_log"),      desc = "Git Log" },
      { "<leader>gL", LazyVim.pick("git_log_file"), desc = "Git Log File" },
      { "<leader>gs", LazyVim.pick("git_status"),   desc = "Git Status" },
      { "<leader>gS", LazyVim.pick("git_stash"),    desc = "Git Stash" },
    },
    opts = {
      picker = {
        icons = LazyVim.config.icons,
        formatters = {
          file = { filename_first = true },
          selected = { show_always = false, unselected = true },
        },
        previewers = {
          diff = { builtin = false },
          git = { builtin = false },
        },
        win = {
          input = {
            -- stylua: ignore
            keys = {
              ["<C-c>"]   = { "toggle_cwd",      mode = { "n", "i" } },
              ["<C-/>"]   = { "toggle_help",     mode = { "n", "i" } },
              ["<S-C-/>"] = { "inspect",         mode = { "n", "i" } },
              ["<C-m>"]   = { "toggle_maximize", mode = { "n", "i" } },
              ["<Tab>"]   = { "toggle_preview",  mode = { "n", "i" } },
              ["<c-w>"]   = { "cycle_win",       mode = { "n", "i" } },
              ["<C-p>"]   = { "history_back",    mode = { "n", "i" } },
              ["<C-n>"]   = { "history_forward", mode = { "n", "i" } },
              ["<C-CR>"]  = { "select_and_next", mode = { "n", "i" } },
              ["<C-i>"]   = { "toggle_ignored",  mode = { "n", "i" } },
              ["<C-h>"]   = { "toggle_hidden",   mode = { "n", "i" } },
            },
          },
        },
      },
    },
  },
  {
    "fnune/recall.nvim",
    optional = true,
    specs = {
      "folke/snacks.nvim",
      keys = {
        { "<leader>'", LazyVim.pick("recall"), desc = "Recall" },
      },
      opts = function(_, opts)
        return vim.tbl_deep_extend("force", opts or {}, {
          picker = {
            actions = require("plugins.recall.picker").actions,
            sources = require("plugins.recall.picker").sources,
          },
        })
      end,
    },
  },
  {
    "folke/trouble.nvim",
    optional = true,
    specs = {
      "folke/snacks.nvim",
      opts = function(_, opts)
        return vim.tbl_deep_extend("force", opts or {}, {
          picker = {
            actions = require("trouble.sources.snacks").actions,
            win = {
              input = {
                keys = {
                  ["<c-t>"] = { "trouble_open", mode = { "n", "i" } },
                },
              },
            },
          },
        })
      end,
    },
  },
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = {
      servers = {
        ["*"] = {
          -- stylua: ignore
          keys = {
            { "grd", function() Snacks.picker.lsp_definitions() end, desc = "Definitions", has = "definition" },
            { "grD", function() Snacks.picker.lsp_declarations() end, desc = "Declarations" },
            { "grr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
            { "grI", function() Snacks.picker.lsp_implementations() end, desc = "Implementations" },
            { "grt", function() Snacks.picker.lsp_type_definitions() end, desc = "Type Definitions" },
            { "gri", function() Snacks.picker.lsp_incoming_calls() end, desc = "Incoming Calls", has = "callHierarchy/incomingCalls" },
            { "gro", function() Snacks.picker.lsp_outgoing_calls() end, desc = "Outgoing Calls", has = "callHierarchy/outgoingCalls" },
            { "<leader>ss", function() Snacks.picker.pick("symbols") end, desc = "Symbols" },
            -- Disable these keymaps from the picker extras in favor of unified `gr` prefix.
            { "gd", false },
            { "gD", false },
            { "gr", false },
            { "gI", false },
            { "gy", false },
            { "gai", false },
            { "gao", false },
          },
        },
      },
    },
  },
}
