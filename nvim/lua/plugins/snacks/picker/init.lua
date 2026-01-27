return {
  {
    "folke/snacks.nvim",
    --stylua: ignore
    keys = {
      { "<leader>nn", function() Snacks.picker.notifications() end, desc = "Notification History" },
      { "<leader>qp", LazyVim.pick("projects"), desc = "Projects" },
      {"<leader>f<space>", LazyVim.pick("pickers"), desc = "Find Pickers" },

      -- git
      { "<leader>gb", LazyVim.pick("git_log_line"),  desc = "Git Blame Line" },
      { "<leader>gB", LazyVim.pick("git_branches"),  desc = "Git Branches" },
      { "<leader>gd", LazyVim.pick("git_diff"), desc = "Git Diff (hunks)" },
      { "<leader>go", LazyVim.pick("git_diff", { base = "origin" }), desc = "Git Diff (origin)" },
      { "<leader>gf", LazyVim.pick("git_files"), desc = "Find Git Files" },
      { "<leader>gl", LazyVim.pick("git_log"), desc = "Git Log" },
      { "<leader>gL", LazyVim.pick("git_log_file"), desc = "Git Log File" },
      { "<leader>gs", LazyVim.pick("git_status"), desc = "Git Status" },
      { "<leader>gS", LazyVim.pick("git_stash"), desc = "Git Stash" },
    },
    opts = {
      picker = {
        layout = {
          preset = "mini",
        },
        icons = LazyVim.config.icons,
        layouts = {
          mini = {
            layout = {
              box = "vertical",
              backdrop = false,
              row = -1,
              height = 0.4,
              {
                win = "input",
                height = 1,
                border = "rounded",
                title = " {source} {live} {flags}",
                title_pos = "left",
              },
              {
                box = "horizontal",
                { win = "list", border = "hpad" },
                { win = "preview", title = "{preview}", width = 0.6, border = "left" },
              },
            },
          },
        },
        formatters = {
          file = {
            filename_first = true,
          },
          selected = {
            show_always = false,
            unselected = true,
          },
        },
        previewers = {
          diff = {
            builtin = false,
          },

          git = {
            builtin = false,
          },
        },
        win = {
          input = {
            keys = {
              ["<C-c>"] = { "toggle_cwd", mode = { "n", "i" } },
              ["<C-/>"] = { "toggle_help", mode = { "n", "i" } },
              ["<S-C-/>"] = { "inspect", mode = { "n", "i" } },
              ["<C-m>"] = { "toggle_maximize", mode = { "i", "n" } },
              ["<Tab>"] = { "toggle_preview", mode = { "i", "n" } },
              ["<c-w>"] = { "cycle_win", mode = { "i", "n" } },
              ["<C-p>"] = { "history_back", mode = { "i", "n" } },
              ["<C-n>"] = { "history_forward", mode = { "i", "n" } },
              ["<C-CR>"] = { "select_and_next", mode = { "i", "n" } },
              ["<C-g>"] = { "grep_in_dir", mode = { "i", "n" } },
              ["<C-f>"] = { "files_in_dir", mode = { "i", "n" } },
              ["<C-space>"] = { "refine_or_cycle_picker", mode = { "i", "n" } },
              ["<bs>"] = { "delete_char_or_pop_refine", mode = { "i", "n" } },
              ["<C-i>"] = { "toggle_ignored", mode = { "i", "n" } },
              ["<C-h>"] = { "toggle_hidden", mode = { "i", "n" } },
            },
          },
        },
      },
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
