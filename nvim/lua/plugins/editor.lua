local icons = require("config").icons

local function setnormal()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end

local function setinsert()
  vim.cmd([[startinsert]])
end

local function noop()
  -- print("BOOP!")
end

-- A 'quick' picker that starts in insert mode and expects the user to accept the current match with <CR>
local function quick_picker(opts)
  local telescope_actions = require("telescope.actions")
  local trouble = require("trouble.providers.telescope")

  return vim.tbl_deep_extend("force", {
    initial_mode = "insert",
    mappings = {
      i = {
        ["<esc>"] = telescope_actions.close,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble.smart_open_with_trouble,
        ["<c-q>"] = false,
        ["<M-q>"] = false,
      },
      n = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble.smart_open_with_trouble,
        ["<C-q>"] = false,
        ["<M-q>"] = false,
      },
    },
  }, opts or {})
end

-- A 'slow' picker that starts in normal mode and expects the user to use / to search
-- and <CR> to 'accept' the search and go back to normal mode.
local function slow_picker(opts)
  local telescope_actions = require("telescope.actions")
  local trouble = require("trouble.providers.telescope")

  return vim.tbl_deep_extend("force", {
    initial_mode = "normal",
    mappings = {
      i = {
        ["<cr>"] = setnormal,
        ["<esc>"] = telescope_actions.close,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble.open_with_trouble,
        ["<C-q>"] = false,
        ["<M-q>"] = false,
      },
      n = {
        ["/"] = setinsert,
        i = noop,
        a = noop,
        I = noop,
        A = noop,
        R = noop,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<C-t>"] = trouble.open_with_trouble,
        ["<C-q>"] = false,
        ["<M-q>"] = false,
      },
    },
  }, opts or {})
end

return {
  -- file explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = "Neotree",
    keys = {
      { "<leader>fE", ":Neotree toggle<cr>", desc = "File tree (root)" },
      { "<leader>E", "<leader>fE", desc = "File tree (root)", remap = true },
      { "<leader>T", ":Neotree float buffers<cr>", desc = "Buffer tree" },
      { "<leader>gg", ":Neotree float git_status<cr>", desc = "Git tree (cwd)" },
      { "<leader>gG", ":Neotree float git_status<cr>", desc = "Git tree (root)" },
    },
    init = function()
      vim.g.neo_tree_remove_legacy_commands = 1
      if vim.fn.argc() == 1 then
        local stat = vim.loop.fs_stat(vim.fn.argv(0))
        if stat and stat.type == "directory" then
          require("neo-tree")
        end
      end
    end,
    opts = {
      default_component_configs = { git_status = { symbols = vim.tbl_extend("force", {}, icons.diff, icons.git) } },
      filesystem = { follow_current_file = true },
    },
  },

  -- search/replace in multiple files
  {
    "windwp/nvim-spectre",
    -- stylua: ignore
    keys = {
      { "<leader>sr", function() require("spectre").open() end, desc = "Replace in files (Spectre)" },
    },
  },

  -- fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    version = false, -- telescope did only one release, so use HEAD for now
    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      { "nvim-telescope/telescope-ui-select.nvim" },
      { "nvim-telescope/telescope-file-browser.nvim" },
      { "nvim-telescope/telescope-symbols.nvim" },
      { "nvim-telescope/telescope-live-grep-args.nvim" },
    },
    keys = {
      { "<leader>p", "<cmd>Telescope<CR>", desc = "Telescope" },
      { "<leader>e", "<cmd>Telescope file_browser<CR>", desc = "File Explorer" },
      { "<leader>t", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>bb", "<cmd>Telescope buffers<CR>", "Buffers" },
      { "<leader>f", "<cmd>Telescope find_files<CR>", desc = "Files" },
      { "<leader>r", "<cmd>Telescope oldfiles<CR>", desc = "Recent Files" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Text in file" },
      { "<leader>*", "<cmd>Telescope grep_string<CR>", desc = "Word under cursor" },
      { "<leader>:", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader><space>", "<cmd>Telescope find_files<cr>", desc = "Find Files (root dir)" },

      -- find / files
      { "<leader>fb", "<cmd>Telescope buffers show_all_buffers=true<cr>", desc = "Buffers (all)" },
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files (root dir)" },
      { "<leader>fF", "<cmd>Telescope find_files cwd=false<cr>", desc = "Find Files (cwd)" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent" },

      -- search
      { "<leader>sa", "<cmd>Telescope autocommands<cr>", desc = "Auto Commands" },
      { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Buffer" },
      { "<leader>sc", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader>sC", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>sd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>sg", "<cmd>Telescope live_grep<cr>", desc = "Grep (root dir)" },
      { "<leader>sG", "<cmd>Telescope live_grep cwd=false<cr>", desc = "Grep (cwd)" },
      { "<leader>sh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
      { "<leader>sH", "<cmd>Telescope highlights<CR>", desc = "Highlights" },
      { "<leader>sj", "<cmd>Telescope jumplist<CR>", desc = "Jumplist" },
      { "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "Keymaps" },
      { "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Jump to Mark" },
      { "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
      { "<leader>so", "<cmd>Telescope vim_options<CR>", desc = "Vim options" },
      { "<leader>sq", "<cmd>Telescope quickfix<CR>", desc = "Quickfix" },
      { "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document Symbols" },
      { "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Workspace Symbols" },
      { "<leader>sw", "<cmd>Telescope grep_string<cr>", desc = "Word (root dir)" },
      { "<leader>sW", "<cmd>Telescope grep_string cwd=false<cr>", desc = "Word (cwd)" },

      -- emoji
      { "<leader>see", "<cmd>lua require'telescope.builtin'.symbols({sources={'emoji'}})<CR>", desc = "Emoji 😀" },
      {
        "<leader>seg",
        "<cmd>lua require'telescope.builtin'.symbols({sources={'gitmoji'}})<CR>",
        desc = "Gitmoji 🚀",
      },
      {
        "<leader>sea",
        "<cmd>lua require'telescope.builtin'.symbols({sources={'kaomoji'}})<CR>",
        desc = "Art (╯°□°）╯︵ ┻━┻",
      },
      {
        "<leader>sem",
        "<cmd>lua require'telescope.builtin'.symbols({sources={'math'}})<CR>",
        desc = "Math Symbols ∑",
      },

      -- git
      { "<leader>gf", "<cmd>Telescope git_files<CR>", desc = "Git files" },
      { "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "Commits" },
      { "<leader>gC", "<cmd>Telescope git_bcommits<CR>", desc = "Buffer Commits" },
      { "<leader>gb", "<cmd>Telescope git_branches<CR>", desc = "Branches" },
      { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Status" },
      { "<leader>gS", "<cmd>Telescope git_stash<CR>", desc = "Stash" },

      -- TODO: config
      -- {"<leader>cc", nvim_config_files, desc = "Neovim Config Files" },
      -- {"<leader>cf", xdg_config_files, desc = "Find Config Files" },
      -- {"<leader>cs", xdg_config_grep, desc = "Search Config Dir" },
      -- {"<leader>cn", ":Neoconf<cr>", desc = "Open Neoconf file" },
      -- {"<leader>cN", ":Neoconf show<cr>", desc = "Show Neoconf" },
      -- {"<leader>cl", ":Neoconf lsp<cr>", desc = "Show Neoconf LSP" },

      -- TODO: implement something like lvim's info: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/info.lua
      -- TODO: implement something like lvim's log: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/which-key.lua#L211-L236
      -- TODO: implement something like lvim's peak:https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/which-key.lua#L173-L178
    },
    opts = function()
      local telescope = require("telescope")
      local telescope_actions = require("telescope.actions")
      local builtin = require("telescope.builtin")
      local themes = require("telescope.themes")
      return {
        defaults = quick_picker(vim.tbl_deep_extend("force", themes.get_ivy(), {
          entry_prefix = "  ",
          prompt_prefix = icons.prompt,
          selection_caret = icons.caret,
          multi_icon = icons.multi,
          color_devicons = true,
        })),
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
          ["ui-select"] = {
            themes.get_dropdown({}),
          },
          file_browser = slow_picker({
            hijack_netrw = true,
            path = "%:p:h",
            cwd_to_path = false,
            respect_gitignore = false,
          }),
        },
        pickers = {
          find_files = {
            hidden = true,
          },
          oldfiles = {
            -- TODO: something like only_project_root = true (doesn't actually exist)
            only_cwd = true,
            -- TODO: add mapping to toggle only_cwd
          },
          buffers = quick_picker({
            theme = "dropdown",
            ignore_current_buffer = false,
            sort_mru = true,
            sort_lastused = true,
            previewer = false,
            mappings = {
              i = {
                -- TODO: Fix case for deleting current buffer (doesn't delete)
                ["<C-d>"] = telescope_actions.delete_buffer,
              },
              n = {
                ["<C-d>"] = telescope_actions.delete_buffer,
              },
            },
          }),
          git_branches = slow_picker(),
          git_status = slow_picker(),
          git_stash = slow_picker(),
        },
      }
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      telescope.load_extension("fzf")
      telescope.load_extension("ui-select")
      telescope.load_extension("file_browser")
      telescope.load_extension("live_grep_args")

      -- local function nvim_config_files()
      --   builtin.find_files({
      --     prompt_title = "Nvim Config Files",
      --     cwd = vim.fn.stdpath("config"),
      --   })
      -- end

      -- local function xdg_config_files()
      --   builtin.find_files({
      --     prompt_title = "Config Files",
      --     cwd = vim.env.XDG_CONFIG_HOME,
      --   })
      -- end

      -- local function xdg_config_grep()
      --   builtin.live_grep({
      --     prompt_title = "Search Config",
      --     search_dirs = { vim.env.XDG_CONFIG_HOME },
      --   })
      -- end
    end,
  },

  -- easily jump to any location and enhanced f/t motions for Leap
  {
    "ggandor/leap.nvim",
    event = "VeryLazy",
    opts = {
      -- max_phase_one_targets = 0,
      highlight_unlabeled_phase_one_targets = true,
      equivalence_classes = {
        " \t\r\n",
        "([{<",
        ")]}>",
        ".,;:!?'",
        "`'\"",
      },
      special_keys = {
        repeat_search = "<enter>",
        next_phase_one_target = "<enter>",
        next_target = "<enter>",
        prev_target = "<s-enter>",
        next_group = "<space>",
        prev_group = "<s-space>",
        multi_accept = "<enter>",
        multi_revert = "<backspace>",
      },
    },
    keys = {
      { "f", "<Plug>(leap-forward-to)", mode = { "n", "x", "o" }, desc = "Leap forward to" },
      { "F", "<Plug>(leap-backward-to)", mode = { "n", "x", "o" }, desc = "Leap backward to" },
      { "t", "<Plug>(leap-forward-till)", mode = { "n", "x", "o" }, desc = "Leap forward till" },
      { "T", "<Plug>(leap-backward-till)", mode = { "n", "x", "o" }, desc = "Leap backward till" },
      { "gw", "<Plug>(leap-from-window)", mode = { "n", "x", "o" }, desc = "Leap from window" },
    },
    config = function(_, opts)
      local leap = require("leap")
      for k, v in pairs(opts) do
        leap.opts[k] = v
      end
    end,
  },

  -- which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      plugins = { spelling = true },
      window = { border = "single" },
      operators = { gs = "Surround", gS = "Surround" },
      show_help = false,
      show_keys = false,
      key_labels = { ["<leader>"] = "SPC" },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      wk.register({
        mode = "n",
        ["gbc"] = "Toggle block comment",
        ["gcc"] = "Toggle line comment",
        ["gco"] = "Comment next line",
        ["gcO"] = "Comment prev line",
        ["gcA"] = "Comment end of line",
      })

      wk.register({
        mode = { "n", "v" },
        ["g"] = { name = "+goto" },
        ["gs"] = { name = "+surround" },
        ["gb"] = "Toggle block comment",
        ["gc"] = "Toggle line comment",
        ["]"] = { name = "+next" },
        ["["] = { name = "+prev" },
        ["<leader><tab>"] = { name = "+tabs" },
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>d"] = { name = "+debug" },
        ["<leader>f"] = { name = "+file/find" },
        ["<leader>g"] = { name = "+git" },
        ["<leader>l"] = { name = "+lsp" },
        ["<leader>q"] = { name = "+quit/session" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>se"] = { name = "+emoji" },
        ["<leader>sn"] = { name = "+noice" },
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
}
