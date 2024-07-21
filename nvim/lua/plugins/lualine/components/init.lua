local icons = require("config").icons

local visible_for_width = require("plugins.lualine.condition").visible_for_width
local visible_for_filetype = require("plugins.lualine.condition").visible_for_filetype
local tabline_active = require("plugins.lualine.condition").tabline_active

--- @class Components
local M = {}

M.macro = {
  function()
    return require("noice").api.status.mode.get()
  end,
  cond = function()
    return package.loaded["noice"] and require("noice").api.status.mode.has()
  end,
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
    -- if excludes() then
    --   return
    -- end

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
  "searchcount",
  timeout = 200,
}

return M
