local icons = require("config").icons

local function live_grep_cbd()
  require("telescope.builtin").live_grep({
    cwd = require("telescope.utils").buffer_dir(),
  })
end

local function live_grep_cwd()
  require("telescope.builtin").live_grep({
    cwd = vim.fn.getcwd(),
  })
end

local function live_grep_files()
  require("telescope.builtin").live_grep({
    grep_open_files = true,
  })
end

local function grep_string_cwd()
  require("telescope.builtin").grep_string({
    cwd = vim.fn.getcwd(),
  })
end

local function grep_string_cbd()
  require("telescope.builtin").grep_string({
    cwd = require("telescope.utils").buffer_dir(),
  })
end

local function grep_string_files()
  require("telescope.builtin").grep_string({
    grep_open_files = true,
  })
end

return {
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
      { "<leader>p", "<cmd>Telescope commands<CR>", desc = "Commands" },
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
      { "<leader>fF", "<cmd>Telescope find_files cwd=true<cr>", desc = "Find Files (cwd)" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent" },
      { "<leader>fg", live_grep_files, desc = "Grep in open files" },
      { "<leader>fw", grep_string_files, desc = "Search word in open files" },

      -- search
      { "<leader>sa", "<cmd>Telescope autocommands<cr>", desc = "Auto Commands" },
      { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Buffer" },
      { "<leader>sc", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader>sC", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>sd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>sg", live_grep_cwd, desc = "Grep (cwd dir)" },
      { "<leader>sG", live_grep_cbd, desc = "Grep (buffer dir)" },
      { "<leader>sh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
      { "<leader>sH", "<cmd>Telescope highlights<CR>", desc = "Highlights" },
      { "<leader>sj", "<cmd>Telescope jumplist<CR>", desc = "Jumplist" },
      { "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "Keymaps" },
      { "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Jump to Mark" },
      { "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
      { "<leader>so", "<cmd>Telescope vim_options<CR>", desc = "Vim options" },
      { "<leader>sq", "<cmd>Telescope quickfix<CR>", desc = "Quickfix" },
      { "<leader>st", "<cmd>Telescope<CR>", desc = "Telescope Builtins" },
      { "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document Symbols" },
      { "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Workspace Symbols" },
      { "<leader>sw", grep_string_cwd, desc = "Word (cwd)" },
      { "<leader>sW", grep_string_cbd, desc = "Word (buffer dir)" },

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
      local telescope_actions = require("telescope.actions")
      local themes = require("telescope.themes")
      local pickers = require("plugins.telescope.pickers")
      return {
        defaults = pickers.quick_picker(vim.tbl_deep_extend("force", themes.get_ivy(), {
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
          file_browser = pickers.slow_picker({
            hijack_netrw = true,
            path = "%:p:h",
            cwd_to_path = false,
            respect_gitignore = false,
          }),
          live_grep_args = {
            auto_quoting = true, -- enable/disable auto-quoting
            -- define mappings, e.g.
            mappings = { -- extend mappings
              i = {
                ["<C-k>"] = require("telescope-live-grep-args.actions").quote_prompt(),
                ["<C-i>"] = require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --iglob " }),
              },
            },
            -- ... also accepts theme settings, for example:
            -- theme = "dropdown", -- use dropdown theme
            -- theme = { }, -- use own theme spec
            -- layout_config = { mirror=true }, -- mirror preview pane
          },
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
          buffers = pickers.quick_picker({
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
          commands = pickers.quick_picker({
            theme = "dropdown",
            sort_mru = true,
            sort_lastused = true,
          }),
          git_branches = pickers.slow_picker(),
          git_status = pickers.slow_picker(),
          git_stash = pickers.slow_picker(),
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
}
