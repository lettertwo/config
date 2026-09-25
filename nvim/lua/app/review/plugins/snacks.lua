-- snacks provides the outline sidebar's picker. The default app also adds it
-- with a full config; snacks.setup() is idempotent (first caller wins), so in
-- embedded review this is a no-op and standalone gets the minimal picker init.
Config.add("folke/snacks.nvim")
local Snacks = require("snacks")

if not Snacks.did_setup then
  Snacks.setup({
    notifier = { level = vim.log.levels.INFO },
    picker = { enabled = true },
    statuscolumn = {
      left = { "sign", "mark" }, -- priority of signs on the left (high to low)
      right = { "fold", "git" }, -- priority of signs on the right (high to low)
      folds = {
        open = true, -- show open fold icons
        git_hl = true, -- use Git Signs hl for fold icons
      },
      git = {
        -- patterns to match Git signs
        patterns = { "GitSign", "MiniDiffSign", "ReviewSign" },
      },
    },
  })
  Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
end
