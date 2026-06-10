---@module "snacks"
return {
  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      notifier = { level = vim.log.levels.INFO },
      image = {},
      indent = {
        filter = function(buf)
          return vim.g.snacks_indent ~= false
            and vim.b[buf].snacks_indent ~= false
            and vim.bo[buf].buftype == ""
            and not vim.list_contains(LazyVim.config.filetypes.ui, vim.bo[buf].filetype)
        end,
        animate = { enabled = false },
        indent = { char = "│" },
        scope = {
          enabled = true,
          only_current = true,
          char = "│",
        },
        chunk = {
          enabled = true,
          only_current = true,
          char = {
            corner_top = "╭",
            corner_bottom = "╰",
            horizontal = "─",
            vertical = "│",
            arrow = "─",
          },
        },
      },
      statuscolumn = {
        left = { "sign", "mark" }, -- priority of signs on the left (high to low)
        right = { "fold", "git" }, -- priority of signs on the right (high to low)
      },
    },
  },
  { import = "plugins.snacks.dashboard" },
  { import = "plugins.snacks.explorer" },
  { import = "plugins.snacks.scratch" },
  { import = "plugins.snacks.picker" },
  { import = "plugins.snacks.lazygit" },
}
