return {
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFindFileToggle" },
    keys = {
      { "<leader>fE", "<cmd>NvimTreeFindFileToggle<cr>", desc = "File tree (cwd)" },
      { "<leader>E", "<leader>fE", remap = true, desc = "File tree (cwd)" },
    },
    opts = {
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
    config = function(_, opts)
      -- HACK: for some reason, this flag is often if not always already set to 1
      -- when this config runs, which causes the user command setup to be skipped.
      vim.g.NvimTreeSetup = 0
      require("nvim-tree").setup(opts)
    end,
  },
}
