local icons = require("config").icons
local filetypes = require("config").filetypes
local Util = require("util")

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

      local function reveal_in_finder()
        local entry = MiniFiles.get_fs_entry()
        if entry ~= nil and entry.path ~= nil then
          if vim.fn.system("open -R " .. entry.path) then
            MiniFiles.close()
          end
        end
      end

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
              { "<C-o>", reveal_in_finder, desc = "Reveal in finder" },
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
    cmd = { "Grapple", "CloseUntaggedBuffers", "ToggledTaggedBuffer", "NextTaggedBuffer", "PreviousTaggedBuffer" },
    keys = {
      { "<leader>m", "<cmd>ToggleTaggedBuffer<cr>", desc = "Toggle Buffer Tag" },
      { "<s-l>", "<cmd>NextTaggedBuffer<cr>", desc = "Next tag" },
      { "<s-h>", "<cmd>PreviousTaggedBuffer<cr>", desc = "Previous tag" },
      { "<leader>bc", "<cmd>CloseUntaggedBuffers<cr>", desc = "Close untagged buffers" },
    },
    opts = {
      scope = "git", -- also try out "git_branch"
      style = "basename",
    },
    config = function(_, opts)
      require("grapple").setup(opts)

      -- TODO: Figure out why this is not working; it seems to just nuke the contents of open buffers?
      local function close_untagged_buffers()
        local tags = require("grapple").tags()
        if not tags or #tags == 0 then
          vim.notify("No tags found", vim.log.levels.WARN)
        end
        local bufnrs = vim.api.nvim_list_bufs()
        for _, bufnr in ipairs(bufnrs) do
          local should_close = true
          local bufpath = vim.api.nvim_buf_get_name(bufnr)
          for _, tag in ipairs(tags) do
            if tag.path == bufpath then
              should_close = false
              break
            end
          end
          if should_close then
            vim.notify("would close " .. bufnr .. " " .. bufpath, vim.log.levels.INFO)
            -- Util.delete_buffer(bufnr)
          end
        end
      end

      local function is_ui_buffer(bufnr)
        if not bufnr or bufnr == 0 then
          bufnr = vim.api.nvim_get_current_buf()
        end
        local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
        return vim.tbl_contains(filetypes.ui, ft)
      end

      vim.api.nvim_create_user_command("CloseUntaggedBuffers", close_untagged_buffers, {})

      vim.api.nvim_create_user_command("ToggleTaggedBuffer", function()
        if is_ui_buffer() then
          vim.notify("Cannot tag a UI buffer", vim.log.levels.WARN)
        else
          require("grapple").toggle()
        end
      end, {})

      vim.api.nvim_create_user_command("NextTaggedBuffer", function()
        if is_ui_buffer() then
          -- TODO: check for another window with a non-ui buffer and cycle there?
          vim.notify("Cannot cycle tags in UI buffer", vim.log.levels.WARN)
        else
          require("grapple").cycle_tags("next")
        end
      end, {})

      vim.api.nvim_create_user_command("PreviousTaggedBuffer", function()
        if is_ui_buffer() then
          -- TODO: check for another window with a non-ui buffer and cycle there?
          vim.notify("Cannot cycle tags in UI buffer", vim.log.levels.WARN)
        else
          require("grapple").cycle_tags("prev")
        end
      end, {})
    end,
  },
}
