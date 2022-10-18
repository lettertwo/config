local location = require("config.location")

local window_width_limit = 70

local function visible_for_width(limit)
  limit = limit == nil and window_width_limit or limit
  return vim.fn.winwidth(0) > limit
end

local excluded_filetypes = {
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
  "TelescopePrompt",
}

local function visible_for_filetype()
  return not vim.tbl_contains(excluded_filetypes, vim.bo.filetype)
end

-- Only show tabline if we have more than one tab open.
local function tabline_active()
  return #vim.api.nvim_list_tabpages() > 1
end

local tabs = {
  "tabs",
  mode = 0,
  cond = function()
    return visible_for_filetype() and tabline_active()
  end,
}

local filetype = { "filetype", colored = false, icon_only = true }

local filename = { "filename" }

local filepath = {
  "filename",
  file_status = false,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
  cond = function()
    return visible_for_width(140) and visible_for_filetype()
  end,
}

local filepath_inactive = {
  "filename",
  file_status = true,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
}

local branch = {
  -- "b:gitsigns_head",
  "branch",
  icon = " ",
  color = { gui = "bold" },
  cond = visible_for_width,
}

local breadcrumbs = {
  location.get_location,
  cond = function()
    return location.is_available() and visible_for_filetype()
  end,
}

local icons = {
  added = " ",
  modified = " ",
  removed = " ",
  error = " ",
  warn = " ",
  info = " ",
  hint = " ",
  treesitter = " ",
  diagnostics = " ",
  formatting = " ",
  persisting = " ",
  not_persisting = " ",
  copilot = " ",
}

local diff = {
  "diff",
  symbols = { added = icons.added, modified = icons.modified, removed = icons.removed },
  cond = nil,
}

local diagnostics = {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  symbols = { error = icons.error, warn = icons.warn, info = icons.info, hint = icons.hint },
}

-- Adapted from https://github.com/LunarVim/LunarVim/blob/48320e/lua/lvim/core/lualine/components.lua#L82
local services = {
  function()
    local buf_clients = vim.lsp.buf_get_clients()
    local buf_ft = vim.bo.filetype
    local diagnostic_providers = {}
    local formatting_providers = {}
    local copilot_active = false

    -- add lsp clients
    for _, client in pairs(buf_clients) do
      if client.name ~= "null-ls" and client.name ~= "copilot" then
        table.insert(diagnostic_providers, client.name)
      end
      if client.name == "copilot" then
        copilot_active = true
      end
    end

    -- add null-ls sources
    local _, sources = pcall(require, "null-ls.sources")
    if sources then
      local methods = require("null-ls").methods

      -- add formatter
      for _, formatter in pairs(sources.get_available(buf_ft, methods.FORMATTING)) do
        table.insert(formatting_providers, formatter.name)
      end

      -- add linter/diagnostics
      for _, linter in pairs(sources.get_available(buf_ft, methods.DIAGNOSTICS)) do
        table.insert(diagnostic_providers, linter.name)
      end
    end

    local display = {}
    if #diagnostic_providers > 0 then
      table.insert(display, icons.diagnostics .. table.concat(vim.fn.uniq(diagnostic_providers), ", "))
    end

    -- add formatters
    if #formatting_providers > 0 then
      table.insert(display, icons.formatting)
    end

    -- add copilot
    if copilot_active then
      table.insert(display, icons.copilot)
    end

    -- add treesitter
    if next(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()]) then
      table.insert(display, icons.treesitter)
    end

    -- add persisting
    if vim.g.persisting then
      table.insert(display, icons.persisting)
    else
      table.insert(display, icons.not_persisting)
    end

    return table.concat(display, " ")
  end,
}

require("lualine").setup({
  options = {
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
    disabled_filetypes = { "alpha", "NvimTree", "Outline", "netrw" },
    globalstatus = true,
  },
  sections = {
    lualine_a = { tabs, "mode" },
    lualine_b = { branch },
    lualine_c = {},
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
  tabline = {},
  winbar = {
    lualine_a = { filetype, filename },
    lualine_b = {},
    lualine_c = { breadcrumbs },
    lualine_x = {},
    lualine_y = { filepath },
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
