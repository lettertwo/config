local recall_sources = require("plugins.snacks.picker.sources.recall")
local directories_sources = require("plugins.snacks.picker.sources.directories")
local packages_sources = require("plugins.snacks.picker.sources.packages")
local scope_sources = require("plugins.snacks.picker.sources.scope")
local symbols_sources = require("plugins.snacks.picker.sources.symbols")

---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local sources = {}

return {
  {
    "folke/snacks.nvim",
    keys = {
      -- recall sources
      { "<leader>'", LazyVim.pick("recall"), desc = "Recall" },

      -- directories sources
      { "<leader>fn", LazyVim.pick("node_modules"), desc = "Find Package (node_modules)" },
      { "<leader>fP", LazyVim.pick("plugins"), desc = "Find Plugin (lazy)" },

      -- packages sources
      { "<leader>fp", LazyVim.pick("packages"), desc = "Find Package" },

      -- scope sources
      { "<leader>ff", LazyVim.pick("files", { scope = "root" }), desc = "Find Files (root dir)" },
      { "<leader>f.", LazyVim.pick("files", { scope = "package" }), desc = "Find Files (package)" },
      { "<leader>fF", LazyVim.pick("files", { scope = "cwd" }), desc = "Find Files (cwd)" },
      { "<leader>fr", LazyVim.pick("recent", { scope = "root" }), desc = "Recent (root)" },
      { "<leader>fR", LazyVim.pick("recent"), desc = "Recent" },
      { "<leader>fw", LazyVim.pick("recent", { scope = "workspace" }), desc = "Recent (workspace)" },
      { "<leader><space>", LazyVim.pick("switch", { scope = "workspace" }), desc = "Switch (workspace)" },
      { "<leader>r", LazyVim.pick("switch", { scope = "root" }), desc = "Switch (root)" },
      { "<leader>R", LazyVim.pick("switch"), desc = "Switch (global)" },
    },
    ---@type snacks.Config
    opts = {
      picker = {
        sources = vim.tbl_deep_extend(
          "error",
          sources,
          recall_sources,
          directories_sources,
          packages_sources,
          scope_sources,
          symbols_sources
        ),
      },
    },
  },
}
