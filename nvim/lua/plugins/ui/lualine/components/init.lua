local icons = LazyVim.config.icons

local visible_for_width = require("plugins.ui.lualine.condition").visible_for_width
local visible_for_filetype = require("plugins.ui.lualine.condition").visible_for_filetype
local tabline_active = require("plugins.ui.lualine.condition").tabline_active

--- @class Components
local M = {}

M.macro = {
  function()
    local register = vim.fn.reg_recording()
    if register == "" then
      return ""
    end
    return "󰑋 " .. register
  end,
  color = "Error",
}

M.tabstop = {
  function()
    return "󰯉 " .. vim.bo.tabstop
  end,
  cond = visible_for_width,
}

M.tabs = {
  "tabs",
  mode = 0,
  cond = visible_for_filetype + tabline_active,
}

M.branch = {
  "b:gitsigns_head",
  icon = "",
  color = { gui = "bold" },
  cond = visible_for_width,
}

M.filepath = {
  "filename",
  file_status = false,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
  color = "Comment",
  cond = visible_for_filetype,
}

-- TODO: add exception for DAP windows; maybe look at the included extension,
-- or otherwise figure out a way to conditionally configure filename.
M.filepath_inactive = {
  "filename",
  file_status = true,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
}

M.filetype = {
  function()
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    local MiniIcons = require("mini.icons")
    local current_path = vim.fs.normalize(
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.fn.fnamemodify((vim.api.nvim_buf_get_name(buf)), ":p")
    )
    local icon = MiniIcons.get("file", current_path)

    if vim.w[win].sticky_win ~= nil then
      icon = "󰐃 " .. icon
    end

    if package.loaded["grapple"] and require("grapple").exists() then
      icon = "󰛢 " .. icon
    end

    return icon
  end,
  cond = visible_for_filetype,
}

M.diff = {
  "diff",
  symbols = {
    added = icons.diff.added,
    modified = icons.diff.modified,
    removed = icons.diff.removed,
  },

  source = function()
    ---@diagnostic disable-next-line: undefined-field
    local gitsigns = vim.b.gitsigns_status_dict
    if gitsigns then
      return {
        added = gitsigns.added,
        modified = gitsigns.changed,
        removed = gitsigns.removed,
      }
    end
  end,

  cond = nil,
}

M.diagnostics = {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  symbols = {
    error = icons.diagnostics.Error,
    warn = icons.diagnostics.Warn,
    info = icons.diagnostics.Info,
    hint = icons.diagnostics.Hint,
  },
}

M.searchcount = {
  function()
    local count
    local icon = ""
    if vim.v.hlsearch == 0 then
      if package.loaded["occurrence"] ~= nil then
        local ok, occurrence = pcall(require, "occurrence")
        if ok and occurrence then
          ok, count = pcall(occurrence.status)
          if ok and count then
            icon = "󱡴 "
          end
        end
      end
    else
      local ok, result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 200 })
      if ok and result then
        count = result
        icon = "󰍉 "
      end
    end

    if not count or not count.current or not count.total then
      return ""
    end
    local denominator = math.min(count.total, 999)
    return string.format("%s[%d/%d]", icon, count.current, denominator)
  end,
}

local sidekick_icons = {
  Error = { " ", "DiagnosticError" },
  Inactive = { " ", "MsgArea" },
  Warning = { " ", "DiagnosticWarn" },
  Normal = { LazyVim.config.icons.kinds.Copilot, "Special" },
}

M.sidekick = {
  function()
    local status = require("sidekick.status").get()
    return status and vim.tbl_get(sidekick_icons, status.kind, 1)
  end,
  cond = function()
    local ok, status = pcall(require, "sidekick.status")
    return ok and status.get() ~= nil
  end,
  color = function()
    local status = require("sidekick.status").get()
    local hl = status and (status.busy and "DiagnosticWarn" or vim.tbl_get(sidekick_icons, status.kind, 2))
    return { fg = Snacks.util.color(hl) }
  end,
}

return M
