local location = require("config.location")

local window_width_limit = 70

local function visible_for_width()
  return vim.fn.winwidth(0) > window_width_limit
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

local tabs = {
  "tabs",
  mode = 1,
  cond = visible_for_filetype,
}

local branch = {
  -- "b:gitsigns_head",
  "branch",
  icon = " ",
  color = { gui = "bold" },
  cond = visible_for_width,
}

local filetype = { "filetype", cond = visible_for_width }

local diff = { "diff", symbols = { added = "  ", modified = " ", removed = " " }, cond = nil }

local persisting = {
  function()
    if vim.g.persisting then
      return " "
    else
      return " "
    end
  end,
  cond = visible_for_width,
}

local treesitter = {
  function()
    local b = vim.api.nvim_get_current_buf()
    if next(vim.treesitter.highlighter.active[b]) then
      return ""
    end
    return ""
  end,
  cond = visible_for_width,
}

local diagnostics = {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  symbols = { error = " ", warn = " ", info = " ", hint = " " },
  cond = visible_for_width,
}

-- Adapted from https://github.com/LunarVim/LunarVim/blob/48320e/lua/lvim/core/lualine/components.lua#L82
local lsp = {
  function()
    local buf_clients = vim.lsp.buf_get_clients()
    local buf_ft = vim.bo.filetype
    local buf_client_names = {}

    -- add client
    for _, client in pairs(buf_clients) do
      if client.name ~= "null-ls" then
        table.insert(buf_client_names, client.name)
      end
    end

    -- add null-ls sources
    local _, sources = pcall(require, "null-ls.sources")
    if sources then
      local methods = require("null-ls").methods

      -- add formatter
      for _, formatter in pairs(sources.get_available(buf_ft, methods.FORMATTING)) do
        table.insert(buf_client_names, formatter.name)
      end

      -- add linter/diagnostics
      for _, linter in pairs(sources.get_available(buf_ft, methods.DIAGNOSTICS)) do
        table.insert(buf_client_names, linter.name)
      end
    end

    return "[" .. table.concat(vim.fn.uniq(buf_client_names), ", ") .. "]"
  end,
  color = { gui = "bold" },
  cond = function()
    return visible_for_width() or vim.lsp.buf_get_clients() == nil
  end,
}

local filepath = {
  "filename",
  file_status = false,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
  cond = visible_for_filetype,
}

-- If we have only one tab open, we will be showing location in the tabline.
-- If we have more than one tab open, we will be showing location in the winbar.
local function winbar_active()
  return vim.fn.tabpagenr("$") > 1
end

require("lualine").setup({
  options = {
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
    disabled_filetypes = { "alpha", "NvimTree", "Outline", "netrw" },
    globalstatus = true,
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { branch },
    lualine_c = { diff },
    lualine_x = { diagnostics, lsp, filetype },
    lualine_y = {},
    lualine_z = { treesitter, persisting },
  },
  inactive_sections = {
    lualine_a = { filepath },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {
    lualine_a = { tabs },
    lualine_b = {},
    lualine_c = {
      {
        location.get_location,
        cond = function()
          return not winbar_active() and location.is_available()
        end,
      },
    },
    lualine_x = {},
    lualine_y = { filepath },
    lualine_z = {},
  },
  winbar = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      {
        location.get_location,
        cond = function()
          return winbar_active() and location.is_available()
        end,
      },
    },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
})
