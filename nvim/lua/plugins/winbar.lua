local icons = require("config").icons.highlighted
local filetypes = require("config").filetypes
local highlights = require("config").highlights
local format_highlight = require("util").format_highlight

local function visible_for_filetype()
  return not vim.tbl_contains(filetypes.ui, vim.bo.filetype)
end

local function excludes()
  if not visible_for_filetype() then
    vim.opt_local.winbar = nil
    return true
  end
  return false
end

local function isempty(value)
  return value == nil or value == ""
end

local function get_buf_option(opt)
  local status_ok, buf_option = pcall(vim.api.nvim_buf_get_option, 0, opt)
  if not status_ok then
    return nil
  else
    return buf_option
  end
end

local filetype = { "filetype", colored = false, icon_only = true }

local filename = { "filename" }

local filepath_inactive = {
  "filename",
  file_status = true,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
}

return {
  {
    "SmiteshP/nvim-navic",
    event = "VeryLazy",
    opts = {
      icons = icons,
      separator = icons.separator,
      highlight = false,
    },
  },
  {
    "SmiteshP/nvim-gps",
    event = "VeryLazy",
    opts = {
      separator = icons.separator,
      icons = {
        ["array-name"] = icons.kinds.Array,
        ["boolean-name"] = icons.kinds.Boolean,
        ["class-name"] = icons.kinds.Class,
        ["container-name"] = icons.kinds.Container,
        ["date-name"] = icons.kinds.Date,
        ["date-time-name"] = icons.kinds.DateTime,
        ["float-name"] = icons.kinds.Number,
        ["function-name"] = icons.kinds.Function,
        ["inline-table-name"] = icons.kinds.Object,
        ["integer-name"] = icons.kinds.Number,
        ["label-name"] = icons.kinds.Label,
        ["mapping-name"] = icons.kinds.Object,
        ["method-name"] = icons.kinds.Method,
        ["module-name"] = icons.kinds.Module,
        ["null-name"] = icons.kinds.Null,
        ["number-name"] = icons.kinds.Number,
        ["object-name"] = icons.kinds.Object,
        ["sequence-name"] = icons.kinds.Array,
        ["string-name"] = icons.kinds.String,
        ["table-name"] = icons.kinds.Object,
        ["tag-name"] = icons.kinds.Tag,
        ["time-name"] = icons.kinds.Time,
        ["title-name"] = icons.kinds.Title,
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      local gps = require("nvim-gps")
      local navic = require("nvim-navic")
      -- local grapple = {
      --   function()
      --     return " "
      --   end,
      --   cond = require("grapple").exists,
      -- }

      local function is_available()
        return not excludes() and (navic.is_available() or gps.is_available())
      end

      local breadcrumbs = {
        -- TODO: Implement symbol cache.
        -- See https://github.com/glepnir/lspsaga.nvim/blob/main/lua/lspsaga/symbolwinbar.lua
        function()
          if excludes() then
            return
          end

          local location = ""

          if navic.is_available() then
            local status_ok, navic_data = pcall(navic.get_data)
            if status_ok and navic_data then
              for i, data in ipairs(navic_data) do
                location = location .. data.icon .. format_highlight(data.name, highlights.Text)
                if i < #navic_data then
                  location = location .. icons.separator
                end
              end
            end
          elseif gps.is_available() then
            local status_ok, gps_data = pcall(gps.get_data)
            if status_ok and gps_data then
              for i, data in ipairs(gps_data) do
                location = location .. data.icon .. format_highlight(data.text, highlights.Text)
                if i < #gps_data then
                  location = location .. icons.separator
                end
              end
            end
          end

          if not isempty(location) and get_buf_option("mod") then
            location = location .. " " .. format_highlight("", "diffChanged")
          end

          return isempty(location) and nil or location
        end,
        cond = function()
          return is_available() and visible_for_filetype()
        end,
      }

      return vim.tbl_extend("force", opts, {
        winbar = {
          lualine_a = { filetype, filename },
          -- lualine_a = { grapple, filetype, filename },
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
      })
    end,
  },
}
