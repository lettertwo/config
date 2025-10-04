local actions = require("plugins.editor.snacks-picker.actions")
local grapple_actions = require("plugins.editor.snacks-picker.actions.grapple")
local refine_actions = require("plugins.editor.snacks-picker.actions.refine")
local sources = require("plugins.editor.snacks-picker.sources")
local grapple_sources = require("plugins.editor.snacks-picker.sources.grapple")
local directories_sources = require("plugins.editor.snacks-picker.sources.directories")
local packages_sources = require("plugins.editor.snacks-picker.sources.packages")
local scope_sources = require("plugins.editor.snacks-picker.sources.scope")
local symbols_sources = require("plugins.editor.snacks-picker.sources.symbols")

return {
  { "nvim-telescope/telescope.nvim", enabled = false },
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      ---@module "snacks"
      ---@type snacks.Config
      local local_opts = {
        picker = {
          layout = {
            preset = "mini",
          },
          icons = LazyVim.config.icons,
          layouts = {
            mini = {
              preview = false,
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
          actions = vim.tbl_deep_extend(
            "error",
            (opts and opts.actions) or {},
            actions,
            grapple_actions,
            refine_actions
          ),
          sources = vim.tbl_deep_extend(
            "error",
            (opts and opts.sources) or {},
            sources,
            grapple_sources,
            directories_sources,
            packages_sources,
            scope_sources,
            symbols_sources
          ),
          win = {
            input = {
              keys = {
                -- to close the picker on ESC instead of going to normal mode,
                -- add the following keymap to your config
                ["<Esc>"] = { "close_normal", mode = { "n", "i" } },
                ["<C-c>"] = { "toggle_cwd", mode = { "n", "i" } },
                -- ["<CR>"] = { "confirm", mode = { "n", "i" } },
                -- ["G"] = "list_bottom",
                -- ["gg"] = "list_top",
                -- ["j"] = "list_down",
                -- ["k"] = "list_up",
                -- ["/"] = "toggle_focus",
                -- ["q"] = "close",
                ["<C-/>"] = { "toggle_help", mode = { "n", "i" } },
                ["<S-C-/>"] = { "inspect", mode = { "n", "i" } },
                -- ["<c-a>"] = { "select_all", mode = { "n", "i" } },
                ["<C-m>"] = { "toggle_maximize", mode = { "i", "n" } },
                ["<Tab>"] = { "toggle_preview", mode = { "i", "n" } },
                ["<c-w>"] = { "cycle_win", mode = { "i", "n" } },
                -- ["<C-w>"] = { "<c-s-w>", mode = { "i" }, expr = true, desc = "delete word" },
                ["<C-p>"] = { "history_back", mode = { "i", "n" } },
                ["<C-n>"] = { "history_forward", mode = { "i", "n" } },
                ["<C-CR>"] = { "select_and_next", mode = { "i", "n" } },
                -- ["<S-Tab>"] = { "select_and_prev", mode = { "i", "n" } },
                -- ["<Down>"] = { "list_down", mode = { "i", "n" } },
                -- ["<Up>"] = { "list_up", mode = { "i", "n" } },
                -- ["<c-j>"] = { "list_down", mode = { "i", "n" } },
                -- ["<c-k>"] = { "list_up", mode = { "i", "n" } },
                -- ["<c-n>"] = { "list_down", mode = { "i", "n" } },
                -- ["<c-p>"] = { "list_up", mode = { "i", "n" } },
                -- ["<c-b>"] = { "preview_scroll_up", mode = { "i", "n" } },
                ["<C-d>"] = { "smart_scroll_down", mode = { "i", "n" } },
                ["<C-u>"] = { "smart_scroll_up", mode = { "i", "n" } },
                -- ["<c-f>"] = { "preview_scroll_down", mode = { "i", "n" } },
                --
                -- ["<C-g>"] = false,
                ["<C-g>"] = { "grep_in_dir", mode = { "i", "n" } },
                ["<C-f>"] = { "files_in_dir", mode = { "i", "n" } },
                ["<C-space>"] = { "refine_or_cycle_picker", mode = { "i", "n" } },
                ["<bs>"] = { "delete_char_or_pop_refine", mode = { "i", "n" } },
                -- ["<c-space>"] = { "toggle_live", mode = { "i", "n" } },
                --
                -- ["<ScrollWheelDown>"] = { "list_scroll_wheel_down", mode = { "i", "n" } },
                -- ["<ScrollWheelUp>"] = { "list_scroll_wheel_up", mode = { "i", "n" } },
                -- ["<c-v>"] = { "edit_vsplit", mode = { "i", "n" } },
                -- ["<c-s>"] = { "edit_split", mode = { "i", "n" } },
                -- ["<c-q>"] = { "qflist", mode = { "i", "n" } },
                ["<C-i>"] = { "toggle_ignored", mode = { "i", "n" } },
                ["<C-h>"] = { "toggle_hidden", mode = { "i", "n" } },
                ["<C-e>"] = { "mini_files", mode = { "i", "n" } },
                ["<C-y>"] = { "yank_to_clipboard", mode = { "i", "n" } },
              },
            },
          },
        },
      }

      return vim.tbl_deep_extend("force", opts or {}, local_opts)
    end,

    --stylua: ignore
  keys = {
      { "<leader><space>", LazyVim.pick("switch", { scope = "workspace" }), desc = "Switch (workspace)" },
      { "<leader>r", LazyVim.pick("switch", { scope = "root" }), desc = "Switch (root)" },
      { "<leader>R", LazyVim.pick("switch"), desc = "Switch (global)" },
      { "<leader>'", LazyVim.pick("grapple"), desc = "Grapple" },
      { "<leader>nn", function() Snacks.picker.notifications() end, desc = "Notification History" },
      { "<leader>qp", LazyVim.pick("projects"), desc = "Projects" },

      -- find
      { "<leader>ff", LazyVim.pick("files", { scope = "root" }), desc = "Find Files (root dir)" },
      { "<leader>f.", LazyVim.pick("files", { scope = "package" }), desc = "Find Files (package)" },
      { "<leader>fF", LazyVim.pick("files", { scope = "cwd" }), desc = "Find Files (cwd)" },
      { "<leader>fp", LazyVim.pick("packages"), desc = "Find Package" },
      { "<leader>fn", LazyVim.pick("node_modules"), desc = "Find Package (node_modules)" },
      { "<leader>fP", LazyVim.pick("plugins"), desc = "Find Plugin (lazy)" },
      { "<leader>fr", LazyVim.pick("recent", { scope = "root" }), desc = "Recent (root)" },
      { "<leader>fR", LazyVim.pick("recent"), desc = "Recent" },
      { "<leader>fw", LazyVim.pick("recent", { scope = "workspace" }), desc = "Recent (workspace)" },

      -- git
      { "<leader>gb", LazyVim.pick("git_log_line"),  desc = "Git Blame Line" },
      { "<leader>gB", LazyVim.pick("git_branches"),  desc = "Git Branches" },
      { "<leader>gd", LazyVim.pick("git_diff_file"), desc = "Git Diff (hunks)" },
      { "<leader>gf", LazyVim.pick("git_files"), desc = "Find Git Files" },
      { "<leader>gl", LazyVim.pick("git_log"), desc = "Git Log" },
      { "<leader>gL", LazyVim.pick("git_log_file"), desc = "Git Log File" },
      { "<leader>gs", LazyVim.pick("git_status"), desc = "Git Status" },
      { "<leader>gS", LazyVim.pick("git_stash"), desc = "Git Stash" },

      -- grep
      { "<leader>sg", LazyVim.pick("grep", { scope = 'workspace' }), desc = "Grep (workspace)" },
      { "<leader>sG", LazyVim.pick("grep", { scope = 'root' }), desc = "Grep (root dir)" },
      { "<leader>s.", LazyVim.pick("grep", { scope = 'package' }), desc = "Grep (package)" },
      -- { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      -- { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
      -- { "<leader>sw", LazyVim.pick("grep_word"), desc = "Visual selection or word (Root Dir)", mode = { "n", "x" } },
      -- { "<leader>sW", LazyVim.pick("grep_word", { root = false }), desc = "Visual selection or word (cwd)", mode = { "n", "x" } },

      -- search
      -- { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
      -- { '<leader>s/', function() Snacks.picker.search_history() end, desc = "Search History" },
      -- { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
      -- { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      -- { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
      -- { "<leader>sC", function() Snacks.picker.commands({ layout = { preset = "vscode" } }) end, desc = "Commands" },
      -- { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      -- { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
      -- { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
      -- { "<leader>sH", function() Snacks.picker.highlights() end, desc = "Highlights" },
      -- { "<leader>si", function() Snacks.picker.icons() end, desc = "Icons" },
      -- { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps" },
      -- { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      -- { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location List" },
      -- { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
      -- { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
      -- { "<leader>sp", function() Snacks.picker.lazy() end, desc = "Search for Plugin Spec" },
      -- { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
      -- { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume" }, -- TODO: add refine support to resume picker
      -- { "<leader>su", function() Snacks.picker.undo({ pattern= "'", sort = { fields = { "seq:desc" } }, layout = { preview = true } }) end, desc = "Undo History" },
      -- { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
      -- { "<leader>qp", function() Snacks.picker.projects() end, desc = "Projects" },
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
    opts = function()
      local Keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- stylua: ignore
      vim.list_extend(Keys, {
        { "grd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition", has = "definition" },
        { "grD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
        { "grr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
        { "gri", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
        { "grt", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto T[y]pe Definition" },
        { "<leader>ss", function() Snacks.picker.pick("symbols") end, desc = "Symbols" },
        { "<leader>sl", function() Snacks.picker.lsp_symbols({ filter = {default = true }, layout = { preset = "vscode", preview = "main" } }) end, desc = "LSP Symbols" },
        -- { "<leader>st", function() Snacks.picker.treesitter({ layout = { preset = "vscode", preview = "main" } }) end, desc = "TS Symbols" },
        { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
      })
    end,
  },
}
