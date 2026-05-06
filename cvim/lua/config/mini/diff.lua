local map = vim.keymap.set

---@class Config.MiniDiff
local MiniDiffConfig = {}

function MiniDiffConfig.setup()
  Config.add("nvim-mini/mini.nvim")

  local MiniDiff = require("mini.diff")

  local MiniGit = require("mini.git")

  MiniDiff.setup({ linematch = 200 })
  MiniGit.setup()

  map("n", "<leader>go", MiniDiff.toggle_overlay, { desc = "Show diff overlay" })
  map("n", "<leader>gs", MiniGit.show_at_cursor, { desc = "Show diff at cursor" })
  map("x", "<leader>gs", MiniGit.show_at_cursor, { desc = "Show diff for selection" })
  map("n", "<leader>ga", "<Cmd>Git diff --cached<CR>", { desc = "Added diff" })
  map("n", "<leader>gA", "<Cmd>Git diff --cached -- %<CR>", { desc = "Added diff buffer" })
  map("n", "<leader>gc", "<Cmd>Git commit<CR>", { desc = "Commit" })
  map("n", "<leader>gC", "<Cmd>Git commit --amend<CR>", { desc = "Commit amend" })
  map("n", "<leader>gd", "<Cmd>Git diff<CR>", { desc = "Diff" })
  map("n", "<leader>gD", "<Cmd>Git diff -- %<CR>", { desc = "Diff buffer" })
end

return MiniDiffConfig
