local icons = require("config").icons

return {
  -- file explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    -- stylua: ignore start
    keys = {
      { "<leader>fE", function() require("neo-tree.command").execute({ toggle = true, dir = vim.loop.cwd() }) end, desc = "File tree (cwd)" },
      { "<leader>E", "<leader>fE", remap = true, desc = "File tree (cwd)" },
    },
    -- stylua: ignore end
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
      filesystem = { follow_current_file = { enabled = true } },
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
