return {
  { "akinsho/bufferline.nvim", enabled = false },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "echasnovski/mini.icons",
      "lewis6991/gitsigns.nvim",
    },
    opts = function(_, opts)
      local filetypes = require("lazyvim.config").filetypes

      local breadcrumbs = require("plugins.ui.lualine.components.breadcrumbs")
      local buffer = require("plugins.ui.lualine.components.buffer")
      local services = require("plugins.ui.lualine.components.services")
      local mode = require("plugins.ui.lualine.components.mode")

      local components = require("plugins.ui.lualine.components")
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

      local local_opts = {
        options = {
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = filetypes.ui,
          globalstatus = true,
        },
        sections = {
          lualine_a = { tabs, mode, searchcount },
          lualine_b = { macro, branch },
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

      return vim.tbl_deep_extend("force", opts or {}, local_opts)
    end,
    config = function(_, opts)
      -- Patch `lualine.utils.utils.is_focused` to force inactive state when nvim focus is lost.
      -- Based on:  https://github.com/nvim-lualine/lualine.nvim/issues/498#issuecomment-997346570
      local force_inactive = false
      local is_focused = require("lualine.utils.utils").is_focused
      ---@diagnostic disable-next-line: duplicate-set-field
      require("lualine.utils.utils").is_focused = function()
        return not force_inactive and is_focused()
      end

      require("lualine").setup(opts)

      vim.api.nvim_create_autocmd({ "FocusGained", "FocusLost" }, {
        group = vim.api.nvim_create_augroup("lualine_force_inactive", { clear = true }),
        callback = function(e)
          force_inactive = e.event == "FocusLost"
          require("lualine").refresh()
        end,
      })

      vim.api.nvim_create_autocmd({ "ColorScheme" }, {
        group = vim.api.nvim_create_augroup("lualine_color_scheme_change", { clear = true }),
        callback = function()
          -- FIXME: This _almost_ works, but any non-normal modes that were activated before
          -- colorscheme change will have broken separator highlights.
          require("lualine").setup()
          require("lualine").refresh({
            place = { "statusline", "tabline", "winbar" },
            scope = "all",
          })
        end,
      })
    end,
  },
}
