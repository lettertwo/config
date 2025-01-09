return {
  {
    "echasnovski/mini.files",
    version = false,
    keys = {
      {
        "<leader>fe",
        function()
          require("plugins.editor.mini-files.actions").open_buffer()
        end,
        desc = "File explorer (buffer)",
      },
      {
        "<leader>e",
        function()
          require("plugins.editor.mini-files.actions").open_buffer()
        end,
        desc = "File explorer (buffer)",
      },
      {
        "<leader>~",
        function()
          require("plugins.editor.mini-files.actions").open_cwd()
        end,
        desc = "File explorer (cwd)",
      },
    },
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
      local actions = require("plugins.editor.mini-files.actions")
      local keymaps = require("util").create_buffer_keymap({})

      MiniFiles.setup(opts)

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
}