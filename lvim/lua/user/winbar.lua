local M = {}

M.winbar_exclude = {
  "help",
  "startify",
  "dashboard",
  "packer",
  "neogitstatus",
  "NvimTree",
  "Trouble",
  "alpha",
  "Outline",
  "spectre_panel",
  "toggleterm",
}

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

local function get_filename()
  local filename = vim.fn.expand("%:t")
  local extension = vim.fn.expand("%:e")

  if not isempty(filename) then
    local file_icon, file_icon_color = require("nvim-web-devicons").get_icon_color(
      filename,
      extension,
      { default = true }
    )

    local hl_group = "FileIconColor" .. extension

    vim.api.nvim_set_hl(0, hl_group, { fg = file_icon_color })
    if isempty(file_icon) then
      file_icon = " "
      file_icon_color = " "
    end

    return " " .. "%#" .. hl_group .. "#" .. file_icon .. "%*" .. " " .. "%#NavicText#" .. filename .. "%*"
  end
end

local function get_location()
  local status_gps_ok, gps = pcall(require, "nvim-navic")
  if not status_gps_ok then
    return ""
  end

  local status_ok, gps_location = pcall(gps.get_location, {
    highlight = true,
    separator = "  ",
  })

  if not status_ok then
    return ""
  end

  if not gps.is_available() or gps_location == "error" then
    return ""
  end

  if not isempty(gps_location) then
    return "%#NavicSeparator#%* " .. gps_location
  else
    return ""
  end
end

local function excludes()
  if vim.tbl_contains(M.winbar_exclude, vim.bo.filetype) then
    vim.opt_local.winbar = nil
    return true
  end
  return false
end

function M.get_winbar()
  if excludes() then
    return
  end
  local value = get_filename()
  local location_added = false
  if not isempty(value) then
    local location = get_location()
    value = value .. " " .. location
    if not isempty(location) then
      location_added = true
    end
  end

  if not isempty(value) and get_buf_option("mod") then
    local mod = "%#diffChanged#%*"

    if location_added then
      value = value .. " " .. mod
    else
      value = value .. mod
    end
  end

  local status_ok, _ = pcall(vim.api.nvim_set_option_value, "winbar", value, { scope = "local" })
  if not status_ok then
    return
  end
end

return M
