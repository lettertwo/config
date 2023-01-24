local icons = require("config").icons
local Util = require("util")

-- local icons = require("config").icons.highlighted
local filetypes = require("config").filetypes

local window_width_limit = 70

local function visible_for_width(limit)
  limit = limit == nil and window_width_limit or limit
  return vim.fn.winwidth(0) > limit
end

local function visible_for_filetype()
  return not vim.tbl_contains(filetypes.ui, vim.bo.filetype)
end

-- Only show tabline if we have more than one tab open.
local function tabline_active()
  return #vim.api.nvim_list_tabpages() > 1
end

local branch = {
  -- "b:gitsigns_head",
  "branch",
  icon = " ",
  color = { gui = "bold" },
  cond = visible_for_width,
}

local tabs = {
  "tabs",
  mode = 0,
  cond = function()
    return visible_for_filetype() and tabline_active()
  end,
}

local mode = {
  function()
    if vim.b.visual_multi == 1 then
      local vm = vim.b.VM_Selection
      if vm then
        return "V-MULTI " .. vm.Vars.index + 1 .. "/" .. #vm.Regions
      else
        return "V-MULTI"
      end
    end
    return require("lualine.utils.mode").get_mode()
  end,
}

local macro = {
  function()
    return require("noice").api.status.mode.get()
  end,
  cond = function()
    return package.loaded["noice"] and require("noice").api.status.mode.has()
  end,
}

local filepath = {
  "filename",
  file_status = false,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
  color = "Comment",
  cond = visible_for_filetype,
}

local diff = {
  "diff",
  symbols = {
    added = icons.git.added,
    modified = icons.git.modified,
    removed = icons.git.removed,
  },
  cond = nil,
}

local diagnostics = {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  symbols = {
    error = icons.diagnostics.Error,
    warn = icons.diagnostics.Warn,
    info = icons.diagnostics.Info,
    hint = icons.diagnostics.Hint,
  },
}

-- Adapted from https://github.com/LunarVim/LunarVim/blob/48320e/lua/lvim/core/lualine/components.lua#L82
local services = {
  function()
    local status = Util.service_status()
    local display = {}

    if #status.diagnostic_providers > 0 then
      table.insert(display, icons.diagnostics .. table.concat(vim.fn.uniq(status.diagnostic_providers), ", "))
    end

    -- add formatters
    if #status.formatting_providers > 0 then
      table.insert(display, icons.services.formatting)
    end

    -- add copilot
    if status.copilot_active then
      table.insert(display, icons.services.copilot)
    end

    -- add treesitter
    if status.treesitter_active then
      table.insert(display, icons.services.treesitter)
    end

    if status.session_active then
      table.insert(display, icons.services.persisting)
    else
      table.insert(display, icons.services.not_persisting)
    end

    if status.lazy_updates then
      table.insert(display, require("lazy.status").updates())
    end

    return table.concat(display, " ")
  end,
}

return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = require("config").filetypes.ui,
        globalstatus = true,
      },
      sections = {
        lualine_a = { tabs, mode, macro },
        lualine_b = { branch },
        lualine_c = { filepath },
        lualine_x = { diff, diagnostics },
        lualine_y = {},
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
    },
  },
}
