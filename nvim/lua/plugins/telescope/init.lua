local icons = require("config").icons
local Util = require("util")

local function live_grep_cbd()
  require("telescope.builtin").live_grep({
    cwd = require("telescope.utils").buffer_dir(),
    prompt_title = "Live Grep (buffer dir)",
  })
end

local function live_grep_cwd()
  require("telescope.builtin").live_grep({
    cwd = vim.fn.getcwd(),
    prompt_title = "Live Grep (cwd)",
  })
end

local function live_grep_files()
  require("telescope.builtin").live_grep({
    grep_open_files = true,
    prompt_title = "Live Grep (open files)",
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

local function git_hunks()
  require("plugins.telescope.pickers").git_hunks({ bufnr = 0 })
end

local function git_all_hunks()
  require("plugins.telescope.pickers").git_hunks()
end

return {
  {
    "nvim-telescope/telescope.nvim",
    event = "VeryLazy",
    cmd = "Telescope",
    version = false, -- telescope did only one release, so use HEAD for now
    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      { "nvim-telescope/telescope-ui-select.nvim" },
      { "nvim-telescope/telescope-symbols.nvim" },
      { "nvim-telescope/telescope-live-grep-args.nvim" },
      { "tsakirist/telescope-lazy.nvim" },
    },
    keys = {
      { "<leader>p", "<cmd>Telescope commands<CR>", desc = "Commands" },
      { "<leader>t", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>bb", "<cmd>Telescope buffers<CR>", "Buffers" },
      { "<leader>r", "<cmd>Telescope oldfiles prompt_title=Recent(cwd) cwd_only=true<CR>", desc = "Recent Files" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Text in file" },
      { "<leader>*", "<cmd>Telescope grep_string<CR>", desc = "Word under cursor" },
      { "<leader>:", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader><space>", "<cmd>Telescope find_files<cr>", desc = "Find Files (root dir)" },

      -- find / files
      { "<leader>fb", "<cmd>Telescope buffers show_all_buffers=true<cr>", desc = "Buffers (all)" },
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files (root dir)" },
      { "<leader>fF", "<cmd>Telescope find_files cwd=true<cr>", desc = "Find Files (cwd)" },
      { "<leader>fr", "<cmd>Telescope oldfiles prompt_title=Recent(cwd) cwd_only=true<cr>", desc = "Recent (cwd)" },
      { "<leader>fR", "<cmd>Telescope oldfiles prompt_Title=Recent(all) cwd_only=false<cr>", desc = "Recent (all)" },
      { "<leader>fg", live_grep_files, desc = "Grep in open files" },
      { "<leader>fw", grep_string_files, desc = "Search word in open files" },

      -- search
      { "<leader>sa", "<cmd>Telescope autocommands<cr>", desc = "Auto Commands" },
      { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Buffer" },
      { "<leader>sB", live_grep_files, desc = "Grep (open buffers)" },
      { "<leader>sc", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader>sC", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>sg", live_grep_cwd, desc = "Grep (cwd dir)" },
      { "<leader>sG", live_grep_cbd, desc = "Grep (buffer dir)" },
      { "<leader>sh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
      { "<leader>sH", "<cmd>Telescope highlights<CR>", desc = "Highlights" },
      { "<leader>sj", "<cmd>Telescope jumplist<CR>", desc = "Jumplist" },
      { "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "Keymaps" },
      { "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Jump to Mark" },
      { "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
      { "<leader>so", "<cmd>Telescope vim_options<CR>", desc = "Vim options" },
      { "<leader>sp", "<cmd>Telescope lazy<CR>", desc = "Plugins" },
      { "<leader>sq", "<cmd>Telescope quickfix<CR>", desc = "Quickfix" },
      { "<leader>st", "<cmd>Telescope<CR>", desc = "Telescope Builtins" },
      { "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document Symbols" },
      { "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Workspace Symbols" },
      { "<leader>sw", grep_string_cwd, desc = "Word (cwd)" },
      { "<leader>sW", grep_string_cbd, desc = "Word (buffer dir)" },
      { "<leader>sr", "<cmd>Telescope resume<cr>", desc = "Resume last search" },

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
      { "<leader>gh", git_hunks, desc = "Hunks" },
      { "<leader>gH", git_all_hunks, desc = "Workspace Hunks" },

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
      local actions = require("plugins.telescope.actions")
      return {
        defaults = pickers.quick_picker(vim.tbl_deep_extend("force", themes.get_ivy(), {
          entry_prefix = "  ",
          prompt_prefix = icons.prompt,
          selection_caret = icons.caret,
          multi_icon = icons.multi,
          color_devicons = true,
          path_display = function(opts, path)
            local status = require("telescope.state").get_status(vim.api.nvim_get_current_buf())
            local target_width = vim.api.nvim_win_get_width(status.layout.results.winid)
              - status.picker.selection_caret:len()
              - status.picker.prompt_prefix:len()
              - 2
            path = Util.smart_shorten_path(path, { target_width = target_width, cwd = opts.cwd })
            return path
          end,
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
          lazy = {
            mappings = {
              -- TODO: make this work with mini.files
              open_in_browser = "",
              open_in_file_browser = "",
              -- TODO: see if these are more generalizable similar to <C-E>
              open_in_find_files = "<C-f>",
              open_in_live_grep = "<C-g>",
              open_in_terminal = "",
              open_plugins_picker = "<C-b>", -- Works only after having called first another action
              open_lazy_root_find_files = "",
              open_lazy_root_live_grep = "",
              change_cwd_to_plugin = "",
            },
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
                ["<C-d>"] = actions.delete_buffer,
              },
              n = {
                ["d"] = actions.delete_buffer,
              },
            },
          }),
          commands = pickers.quick_picker({
            theme = "dropdown",
            sort_mru = true,
            sort_lastused = true,
          }),
          git_commits = pickers.quick_picker({
            mappings = {
              i = {
                ["<C-d>"] = actions.open_in_diffview,
              },
              n = {
                ["d"] = actions.open_in_diffview,
              },
            },
          }),
          git_branches = pickers.slow_picker({
            mappings = {
              i = {
                ["<C-d>"] = actions.open_in_diffview,
              },
              n = {
                ["d"] = actions.open_in_diffview,
              },
            },
          }),
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
      telescope.load_extension("live_grep_args")
      telescope.load_extension("lazy")

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

      -- Workaround for https://github.com/nvim-telescope/telescope.nvim/issues/2501
      vim.api.nvim_create_autocmd("WinLeave", {
        callback = function()
          if vim.bo.ft == "TelescopePrompt" and vim.fn.mode() == "i" then
            if vim.fn.mode() == "i" then
              vim.schedule(function()
                vim.cmd("stopinsert")
              end)
            end
          end
        end,
      })
    end,
  },
}
