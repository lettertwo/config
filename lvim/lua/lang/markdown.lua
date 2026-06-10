return {
  {
    "nvim-treesitter/nvim-treesitter",
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      highlight = {
        additional_vim_regex_highlighting = { "markdown" },
      },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = function()
      return {
        checkbox = {
          enabled = true,
          unchecked = { icon = LazyVim.config.icons.task.todo, highlight = "ObsidianTodo" },
          checked = { icon = LazyVim.config.icons.task.done, highlight = "ObsidianDone" },
          custom = {
            active = { raw = "[>]", rendered = LazyVim.config.icons.task.active, highlight = "ObsidianRightArrow" },
            cancelled = { raw = "[~]", rendered = LazyVim.config.icons.task.cancelled, highlight = "ObsidianTilde" },
            important = { raw = "[!]", rendered = LazyVim.config.icons.task.important, highlight = "ObsidianImportant" },
          },
        },
      }
    end,
  },
}
