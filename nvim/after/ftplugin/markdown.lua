local map = vim.keymap.set

Config.add("selimacerbas/live-server.nvim")
Config.add("selimacerbas/markdown-preview.nvim")

require("markdown_preview").setup({
  -- all optional; sane defaults shown
  instance_mode = "takeover", -- "takeover" (one tab) or "multi" (tab per instance)
  port = 0, -- 0 = auto (8421 for takeover, OS-assigned for multi)
  open_browser = true,
  default_theme = "dark", -- "dark" or "light"; initial preview theme
  debounce_ms = 300,
})

map("n", "<leader>cp", function()
  vim.cmd("MarkdownPreview")
end, { desc = "Markdown: preview" })

Config.add("MeanderingProgrammer/render-markdown.nvim")

require("render-markdown").setup({
  checkbox = {
    enabled = true,
    unchecked = { icon = Config.icons.task.todo, highlight = "ObsidianTodo" },
    checked = { icon = Config.icons.task.done, highlight = "ObsidianDone" },
    custom = {
      active = { raw = "[>]", rendered = Config.icons.task.active, highlight = "ObsidianRightArrow" },
      cancelled = { raw = "[~]", rendered = Config.icons.task.cancelled, highlight = "ObsidianTilde" },
      important = { raw = "[!]", rendered = Config.icons.task.important, highlight = "ObsidianImportant" },
    },
  },
})

map("n", "<leader>um", function()
  local rm = require("render-markdown")
  local enabled = require("render-markdown.state").enabled
  if enabled then
    rm.disable()
  else
    rm.enable()
  end
end, { desc = "Markdown: toggle render", buf = 0 })
