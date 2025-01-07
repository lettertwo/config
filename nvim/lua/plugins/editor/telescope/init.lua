local Util = require("util")

return {
  {
    "nvim-telescope/telescope.nvim",
    enabled = false,
    keys = {
      -- { "<leader>bb", "<cmd>Telescope buffers<CR>", "Buffers" },
      -- { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Text in file" },
      -- { "<leader>*", "<cmd>Telescope grep word=true<cr>", desc = "Word under cursor", mode = { "n", "v" } },
      { "<leader>:", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader>r", LazyVim.pick("oldfiles", { cwd = vim.uv.cwd() }), desc = "Recent (cwd)" },
      { "<leader>R", LazyVim.pick("files"), desc = "Find Files (Root Dir)" },
      -- { "<leader>:", false },
      { "<leader><space>", false },
      { "<leader>sh", false },
      { "<leader>,", false },

      -- find / files
      -- { "<leader>fb", "<cmd>Telescope buffers show_all_buffers=true<cr>", desc = "Buffers (all)" },
      -- { "<leader>fo", "<cmd>Telescope oldfiles cwd_only=true<cr>", desc = "oldfiles (cwd)" },
      -- { "<leader>fO", "<cmd>Telescope oldfiles cwd_only=false<cr>", desc = "oldfiles (all)" },
      -- { "<leader>fg", "<cmd>Telescope grep open<cr>", desc = "Grep in open files" },
      -- { "<leader>fw", "<cmd>Telescope grep open word=true<cr>", desc = "Word in open files", mode = { "n", "v" } },
      --
      -- search
      -- { "<leader>sB", "<cmd>Telescope grep open<cr>", desc = "Grep (open buffers)" },
      -- { "<leader>sg", "<cmd>Telescope grep<cr>", desc = "Grep (cwd dir)" },
      -- { "<leader>sG", "<cmd>Telescope grep relative<cr>", desc = "Grep (buffer dir)" },
      { "<leader>sT", "<cmd>Telescope<CR>", desc = "Telescope Builtins" },
      -- { "<leader>sw", "<cmd>Telescope grep word=true<cr>", desc = "Word (cwd)", mode = { "n", "v" } },
      -- { "<leader>sW", "<cmd>Telescope grep relative word=true<cr>", desc = "Word (buffer dir)", mode = { "n", "v" } },
      -- { "<leader>sr", "<cmd>Telescope resume<cr>", desc = "Resume last search" },
      -- { "<leader>su", "<cmd>Telescope undo<cr>", desc = "undo history" },
      -- { "<leader>sy", "<cmd>Telescope yank_history<cr>", desc = "yank history", mode = { "n", "v" } },

      -- emoji
      -- { "<leader>see", "<cmd>lua require'telescope.builtin'.symbols({sources={'emoji'}})<CR>", desc = "Emoji 😀" },
      -- { "<leader>seg", "<cmd>lua require'telescope.builtin'.symbols({sources={'gitmoji'}})<CR>", desc = "Gitmoji 🚀", },
      -- { "<leader>sea", "<cmd>lua require'telescope.builtin'.symbols({sources={'kaomoji'}})<CR>", desc = "Art (╯°□°）╯︵ ┻━┻", },
      -- { "<leader>sem", "<cmd>lua require'telescope.builtin'.symbols({sources={'math'}})<CR>", desc = "Math Symbols ∑", },

      -- git
      -- { "<leader>gc", "<cmd>Telescope git_delta commits<CR>", desc = "Commits" },
      -- { "<leader>gC", "<cmd>Telescope git_delta commits bufnr=0<CR>", desc = "Buffer Commits" },
      -- { "<leader>gB", "<cmd>Telescope git_branches<CR>", desc = "Branches" },
      -- { "<leader>gs", "<cmd>Telescope git_delta status<CR>", desc = "Status" },
      -- { "<leader>gS", "<cmd>Telescope git_stash<CR>", desc = "Stash" },
      -- { "<leader>gh", "<cmd>Telescope git_jump hunks bufnr=0<CR>", desc = "Hunks" },
      -- { "<leader>gH", "<cmd>Telescope git_jump hunks<CR>", desc = "Workspace Hunks" },
      --

      -- { "<leader>tt", "<cmd>Telescope task<cr>", desc = "tasks" },

      -- TODO: implement something like lvim's info: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/info.lua
      -- TODO: implement something like lvim's log: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/which-key.lua#L211-L236
    },
    opts = function()
      local themes = require("telescope.themes")
      local pickers = require("plugins.editor.telescope.pickers")
      local actions = require("plugins.editor.telescope.actions")
      local icons = require("lazyvim.config").icons

      -- local telescope = require("telescope")
      -- telescope.load_extension("undo")
      -- telescope.load_extension("yank_history")
      -- telescope.load_extension("smart_open")
      -- telescope.load_extension("git_delta")
      -- telescope.load_extension("git_jump")
      -- telescope.load_extension("grep")
      -- telescope.load_extension("task")
      --

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
          --   grep = {
          --     auto_quoting = true, -- enable/disable auto-quoting
          --     -- define mappings, e.g.
          --     mappings = { -- extend mappings
          --       i = {
          --         ["<C-'>"] = require("telescope-live-grep-args.actions").quote_prompt(),
          --         ["<C-i>"] = require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --iglob " }),
          --       },
          --     },
          --   },
          --
          --   git_jump = pickers.slow_picker(),
          --   task = pickers.slow_picker(),
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
          buffers = {
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
          },
          command_history = {
            theme = "dropdown",
          },
          commands = {
            sort_mru = true,
            sort_lastused = true,
          },
          builtin = {
            theme = "dropdown",
          },
          --       git_commits = pickers.quick_picker({
          --         mappings = {
          --           i = {
          --             ["<C-d>"] = actions.open_in_diffview,
          --           },
          --           n = {
          --             ["d"] = actions.open_in_diffview,
          --           },
          --         },
          --       }),
          --       git_branches = pickers.slow_picker({
          --         mappings = {
          --           i = {
          --             ["<C-d>"] = actions.open_in_diffview,
          --           },
          --           n = {
          --             ["d"] = actions.open_in_diffview,
          --           },
          --         },
          --       }),
          --       git_status = pickers.slow_picker(),
          --       git_stash = pickers.slow_picker(),
        },
      }
    end,
  },
}
