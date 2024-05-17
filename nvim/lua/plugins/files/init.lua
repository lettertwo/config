local icons = require("config").icons

return {
  -- file tree
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFindFileToggle" },
    keys = {
      { "<leader>fE", "<cmd>NvimTreeFindFileToggle<cr>", desc = "File tree (cwd)" },
      { "<leader>E", "<leader>fE", remap = true, desc = "File tree (cwd)" },
    },
    opts = {
      create_in_closed_folder = true,
      hijack_cursor = true,
      sync_root_with_cwd = true,
      view = {
        adaptive_size = true,
      },
      renderer = {
        full_name = true,
        group_empty = true,
        special_files = {},
        symlink_destination = false,
        indent_markers = {
          enable = false,
        },
        icons = {
          git_placement = "after",
          modified_placement = "after",
          diagnostics_placement = "signcolumn",
          bookmarks_placement = "signcolumn",
          show = {
            file = true,
            folder = true,
            folder_arrow = false,
            git = true,
            modified = true,
            diagnostics = true,
            bookmarks = true,
          },
          glyphs = {
            git = {
              unstaged = vim.trim(icons.git.unstaged),
              staged = vim.trim(icons.git.staged),
              unmerged = vim.trim(icons.git.conflict),
              renamed = vim.trim(icons.git.renamed),
              untracked = vim.trim(icons.git.untracked),
              deleted = vim.trim(icons.git.removed),
              ignored = vim.trim(icons.git.ignored),
            },
          },
        },
      },
      update_focused_file = {
        enable = true,
        update_root = true,
        ignore_list = { "help" },
      },
      git = {
        enable = true,
        show_on_dirs = true,
        show_on_open_dirs = false,
      },
      diagnostics = {
        enable = true,
        show_on_dirs = true,
        show_on_open_dirs = false,
      },
      modified = {
        enable = true,
        show_on_dirs = true,
        show_on_open_dirs = false,
      },
      filters = {
        custom = {
          "^.git$",
        },
      },
      actions = {
        change_dir = {
          enable = false,
          restrict_above_cwd = true,
        },
        open_file = {
          resize_window = true,
          window_picker = {
            chars = "aoeui",
          },
        },
        remove_file = {
          close_window = false,
        },
      },
    },
  },

  {
    "echasnovski/mini.files",
    version = false,
    opts = {
      -- Module mappings created only inside explorer.
      -- Use `''` (empty string) to not create one.
      mappings = {
        close = "q",
        go_in = "l",
        go_in_plus = "<CR>",
        go_out = "<BS>",
        go_out_plus = "h",
        reset = "!",
        reveal_cwd = "@",
        show_help = "g?",
        synchronize = "w",
        trim_left = "<",
        trim_right = ">",
      },

      options = {
        permanent_delete = true,
        use_as_default_explorer = true,
      },

      windows = {
        preview = true,
        width_focus = 50,
        width_nofocus = 15,
        width_preview = 70,
      },
    },
    config = function(_, opts)
      local MiniFiles = require("mini.files")
      local actions = require("plugins.files.actions")
      local keymaps = require("util").create_buffer_keymap({})

      MiniFiles.setup(opts)

      vim.keymap.set("n", "<leader>fe", actions.open_buffer, { desc = "File explorer (buffer)" })
      vim.keymap.set("n", "<leader>e", actions.open_buffer, { desc = "File explorer (buffer)" })
      vim.keymap.set("n", "<leader>~", actions.open_cwd, { desc = "File explorer (cwd)" })

      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesBufferCreate",
        callback = function(args)
          local buf_id = args.data.buf_id
          if buf_id ~= nil then
            keymaps.apply(buf_id, {
              { "<esc>", actions.close, desc = "Close minifiles" },
              { "g.", actions.toggle_dotfiles, desc = "Toggle dotfiles" },
              { "<C-.>", actions.files_set_cwd, desc = "Set cwd" },
              { "<C-s>", actions.split, desc = "Open in split" },
              { "<C-v>", actions.vsplit, desc = "Open in vsplit" },
            })
          end
        end,
      })
    end,
  },
  {
    "cbochs/grapple.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "Grapple", "CloseUntaggedBuffers" },
    keys = {
      { "<leader>m", "<cmd>Grapple toggle<cr>", desc = "Toggle Buffer Tag" },
      { "<s-l>", "<cmd>Grapple cycle_tags next<cr>", desc = "Next tag" },
      { "<s-h>", "<cmd>Grapple cycle_tags prev<cr>", desc = "Previous tag" },
    },
    opts = {
      scope = "git", -- also try out "git_branch"
      style = "basename",
    },
}
