local icons = require("config").icons
local Util = require("util")

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
      { "debugloop/telescope-undo.nvim" },
      { "gbprod/yanky.nvim" },
      { "danielfalk/smart-open.nvim", branch = "0.2.x", dependencies = { "kkharji/sqlite.lua" } },
      { "cbochs/grapple.nvim" },
    },
    keys = {
      { "<leader>bb", "<cmd>Telescope buffers<CR>", "Buffers" },
      { "<leader>r", "<cmd>Telescope smart_open cwd_only=true<CR>", desc = "Recent Files (cwd)" },
      { "<leader>a", "<cmd>Telescope smart_open cwd_only=false<CR>", desc = "Recent Files (all)" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Text in file" },
      { "<leader>*", "<cmd>Telescope grep word=true<cr>", desc = "Word under cursor", mode = { "n", "v" } },
      { "<leader>:", "<cmd>Telescope command_history<cr>", desc = "Command History" },

      -- find / files
      { "<leader>fb", "<cmd>Telescope buffers show_all_buffers=true<cr>", desc = "Buffers (all)" },
      { "<leader>ff", "<cmd>Telescope smart_open cwd_only=true<cr>", desc = "Find files" },
      { "<leader>fF", "<cmd>Telescope smart_open cwd_only=false<cr>", desc = "Find files (all)" },
      { "<leader>fo", "<cmd>Telescope oldfiles cwd_only=true<cr>", desc = "oldfiles (cwd)" },
      { "<leader>fO", "<cmd>Telescope oldfiles cwd_only=false<cr>", desc = "oldfiles (all)" },
      { "<leader>fg", "<cmd>Telescope grep open<cr>", desc = "Grep in open files" },
      { "<leader>fw", "<cmd>Telescope grep open word=true<cr>", desc = "Word in open files", mode = { "n", "v" } },

      -- search
      { "<leader>sa", "<cmd>Telescope autocommands<cr>", desc = "Auto Commands" },
      { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Buffer" },
      { "<leader>sB", "<cmd>Telescope grep open<cr>", desc = "Grep (open buffers)" },
      { "<leader>sc", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader>sC", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>sg", "<cmd>Telescope grep<cr>", desc = "Grep (cwd dir)" },
      { "<leader>sG", "<cmd>Telescope grep relative<cr>", desc = "Grep (buffer dir)" },
      { "<leader>sh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
      { "<leader>sH", "<cmd>Telescope highlights<CR>", desc = "Highlights" },
      { "<leader>sj", "<cmd>Telescope jumplist<CR>", desc = "Jumplist" },
      { "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "Keymaps" },
      { "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Jump to Mark" },
      { "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
      { "<leader>so", "<cmd>Telescope vim_options<CR>", desc = "Vim options" },
      { "<leader>sp", "<cmd>Telescope lazy<CR>", desc = "Plugins" },
      { "<leader>sq", "<cmd>Telescope quickfix<CR>", desc = "Quickfix" },
      { "<leader>sT", "<cmd>Telescope<CR>", desc = "Telescope Builtins" },
      { "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document Symbols" },
      { "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Workspace Symbols" },
      { "<leader>sw", "<cmd>Telescope grep word=true<cr>", desc = "Word (cwd)", mode = { "n", "v" } },
      { "<leader>sW", "<cmd>Telescope grep relative word=true<cr>", desc = "Word (buffer dir)", mode = { "n", "v" } },
      { "<leader>sr", "<cmd>Telescope resume<cr>", desc = "Resume last search" },
      { "<leader>su", "<cmd>Telescope undo<cr>", desc = "undo history" },
      { "<leader>sy", "<cmd>Telescope yank_history<cr>", desc = "yank history", mode = { "n", "v" } },

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
      { "<leader>gc", "<cmd>Telescope git_delta commits<CR>", desc = "Commits" },
      { "<leader>gC", "<cmd>Telescope git_delta commits bufnr=0<CR>", desc = "Buffer Commits" },
      { "<leader>gB", "<cmd>Telescope git_branches<CR>", desc = "Branches" },
      { "<leader>gs", "<cmd>Telescope git_delta status<CR>", desc = "Status" },
      { "<leader>gS", "<cmd>Telescope git_stash<CR>", desc = "Stash" },
      { "<leader>gh", "<cmd>Telescope git_jump hunks bufnr=0<CR>", desc = "Hunks" },
      { "<leader>gH", "<cmd>Telescope git_jump hunks<CR>", desc = "Workspace Hunks" },

      { "<leader><space>", "<cmd>Telescope switch<cr>", desc = "switch to buffer" },

      -- TODO: implement something like lvim's info: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/info.lua
      -- TODO: implement something like lvim's log: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/which-key.lua#L211-L236
    },
    opts = function()
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

          -- Format path and add custom highlighting
          path_display = function(opts, path)
            local target_width = opts.target_width
            if target_width == nil then
              local status = require("telescope.state").get_status(vim.api.nvim_get_current_buf())
              target_width = vim.api.nvim_win_get_width(status.layout.results.winid)
                - status.picker.selection_caret:len()
                - status.picker.prompt_prefix:len()
                - 2
            end

            local basename = Util.title_path(path)
            target_width = target_width - #basename - 1

            local dir_path = Util.smart_shorten_path(
              path.sub(path, 1, #path - #basename),
              { target_width = target_width, cwd = opts.cwd }
            )

            local display = basename
            local highlights = {}

            local display_segments = vim.split(display, Util.SEP)

            if #display_segments > 1 then
              table.insert(highlights, {
                { #display - #display_segments[#display_segments] - 1, #display },
                "TelescopeResultsDiffUntracked",
              })
            end

            if dir_path ~= "" then
              display = string.format("%s %s", display, dir_path)
              table.insert(highlights, {
                { #basename + 1, #display },
                "TelescopePreviewDirectory",
              })
            end
            return display, highlights
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
          grep = {
            auto_quoting = true, -- enable/disable auto-quoting
            -- define mappings, e.g.
            mappings = { -- extend mappings
              i = {
                ["<C-'>"] = require("telescope-live-grep-args.actions").quote_prompt(),
                ["<C-i>"] = require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --iglob " }),
              },
            },
          },
          smart_open = {
            show_scores = false,
            -- ignore_patterns = { "*.git/*", "*/tmp/*" },
            match_algorithm = "fzf",
            -- disable_devicons = false,
            -- open_buffer_indicators = { previous = "👀", others = "🙈" },
            -- TODO: Add mappings for:
            -- <c-r> to narrow to just open buffers
            -- <c-d> to delete open buffer? (or should it be <c-x> to preserve preview scroll?)
            -- toggle cwd_only?
            -- FIXME: refine doesn't work
            -- TODO: add grapple tag status to display (maybe just a hook icon)
            -- TODO: Tagged buffers should have higher priority?
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
          git_jump = pickers.slow_picker(),
          switch = pickers.slow_picker(themes.get_dropdown({})),
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
          command_history = pickers.quick_picker({
            theme = "dropdown",
          }),
          commands = pickers.quick_picker({
            sort_mru = true,
            sort_lastused = true,
          }),
          builtin = pickers.quick_picker({
            theme = "dropdown",
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
      -- patch telescope.log to use nvim.notify() instead of plenary.log

      local mylog = {}

      -- package.loaded["telescope.log"] = mylog

      local telescope = require("telescope")
      telescope.setup(opts)
      telescope.load_extension("fzf")
      telescope.load_extension("ui-select")
      telescope.load_extension("lazy")
      telescope.load_extension("undo")
      telescope.load_extension("yank_history")
      telescope.load_extension("smart_open")
      telescope.load_extension("git_delta")
      telescope.load_extension("git_jump")
      telescope.load_extension("grep")
      telescope.load_extension("switch")
    end,
  },
}
