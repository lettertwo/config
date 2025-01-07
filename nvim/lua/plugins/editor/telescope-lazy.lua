return {
  {
    "tsakirist/telescope-lazy.nvim",
    enabled = false,
    opts = function()
      ----@module "lazyvim"
      LazyVim.on_load("telescope.nvim", function()
        require("telescope").load_extension("lazy")
      end)
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      { "<leader>sp", "<cmd>Telescope lazy<CR>", desc = "Plugins" },
    },
    opts = {
      extensions = {
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
    },
  },
}
