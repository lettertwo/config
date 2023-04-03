local icons = require("config").icons

return {
  {
    "sindrets/diffview.nvim",
    event = "BufReadPost",
    cmd = { "Diffview", "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Diff" },
      { "<leader>gl", "<cmd>DiffviewFileHistory<cr>", desc = "Open History" },
      { "<leader>gL", "<cmd>DiffviewFileHistory %<cr>", desc = "Open File History" },
    },
    opts = function()
      local actions = require("diffview.actions")
      return {
        file_history_panel = {
          win_config = {
            type = "split",
            position = "bottom",
            height = 30,
          },
        },
        keymaps = {
          view = {
            { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
            { "n", "<esc>", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
          },
          file_panel = {
            { "n", "a", actions.toggle_stage_entry, { desc = "Stage / unstage the selected entry." } },
            { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
            { "n", "<esc>", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
          },
          file_history_panel = {
            { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
            { "n", "<esc>", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
          },
        },
      }
    end,
  },
}
