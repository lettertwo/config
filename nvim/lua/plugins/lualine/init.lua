return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "lewis6991/gitsigns.nvim",
    },
    opts = function()
      local filetypes = require("config").filetypes

      local breadcrumbs = require("plugins.lualine.components.breadcrumbs")
      local buffer = require("plugins.lualine.components.buffer")
      local services = require("plugins.lualine.components.services")
      local mode = require("plugins.lualine.components.mode")

      local components = require("plugins.lualine.components")
      local branch = components.branch
      local diagnostics = components.diagnostics
      local diff = components.diff
      local filepath = components.filepath
      local filepath_inactive = components.filepath_inactive
      local filetype = components.filetype
      local macro = components.macro
      local searchcount = components.searchcount
      local tabs = components.tabs
      local tabstop = components.tabstop

      return {
        options = {
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = filetypes.ui,
          globalstatus = true,
        },
        sections = {
          lualine_a = { tabs, mode, macro, searchcount },
          lualine_b = { branch },
          lualine_c = { filepath },
          lualine_x = { diff, diagnostics },
          lualine_y = { tabstop },
          lualine_z = { services },
        },
        inactive_sections = {
          lualine_a = { filepath },
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        winbar = {
          lualine_a = { buffer },
          lualine_b = {},
          lualine_c = { breadcrumbs },
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
        inactive_winbar = {
          lualine_a = {},
          lualine_b = { filetype, filepath_inactive },
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
      }
    end,
  },
}
