return {
  {
    "esmuellert/codediff.nvim",
    -- enabled = false,
    dependencies = { "MunifTanjim/nui.nvim" },
    cmd = "CodeDiff",
    opts = {
      keymaps = {
        view = {
          toggle_explorer = "<leader>E", -- Toggle explorer visibility (explorer mode only)
          next_hunk = "]c", -- Jump to next change
          prev_hunk = "[c", -- Jump to previous change
          next_file = "]f", -- Next file in explorer/history mode
          prev_file = "[f", -- Previous file in explorer/history mode
          diff_get = "do", -- Get change from other buffer (like vimdiff)
          diff_put = "dp", -- Put change to other buffer (like vimdiff)
          open_in_prev_tab = "gf", -- Open current buffer in previous tab (or create one before)
          toggle_stage = "-", -- Stage/unstage current file (works in explorer and diff buffers)
          stage_hunk = "<leader>hs", -- Stage hunk under cursor to git index
          unstage_hunk = "<leader>hu", -- Unstage hunk under cursor from git index
          discard_hunk = "<leader>hr", -- Discard hunk under cursor (working tree only)
          show_help = "g?", -- Show floating window with available keymaps
        },
        explorer = {
          select = "<CR>", -- Open diff for selected file
          hover = "K", -- Show file diff preview
          refresh = "R", -- Refresh git status
          toggle_view_mode = "i", -- Toggle between 'list' and 'tree' views
          stage_all = "S", -- Stage all files
          unstage_all = "U", -- Unstage all files
          restore = "X", -- Discard changes (restore file)
        },
      },
      diff = {
        layout = "inline",
      },
    },
  },
}
