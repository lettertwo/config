local colors = {
  bg = "#202328",
  fg = "#bbc2cf",
  yellow = "#ECBE7B",
  cyan = "#008080",
  darkblue = "#081633",
  green = "#98be65",
  orange = "#FF8800",
  violet = "#a9a1e1",
  magenta = "#c678dd",
  purple = "#c678dd",
  blue = "#51afef",
  red = "#ec5f67",
}

local location = require("config.location")

local window_width_limit = 70

local function hide_in_width()
  return vim.fn.winwidth(0) > window_width_limit
end

local branch = {
  -- "b:gitsigns_head",
  "branch",
  icon = " ",
  color = { gui = "bold" },
  cond = hide_in_width,
}

local filename = { "filename", cond = nil }

local filetype = { "filetype", cond = hide_in_width }

local diff = { "diff", symbols = { added = "  ", modified = " ", removed = " " }, cond = nil }

local persisting = {
  function()
    if vim.g.persisting then
      return " "
    else
      return " "
    end
  end,
  color = { fg = colors.bg },
  cond = hide_in_width,
}

local treesitter = {
  function()
    local b = vim.api.nvim_get_current_buf()
    if next(vim.treesitter.highlighter.active[b]) then
      return ""
    end
    return ""
  end,
  color = { fg = colors.bg },
  cond = hide_in_width,
}

local diagnostics = {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  symbols = { error = " ", warn = " ", info = " ", hint = " " },
  cond = hide_in_width,
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
    return hide_in_width() or vim.lsp.buf_get_clients() == nil
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
    lualine_a = { "mode" },
    lualine_b = { branch, filename },
    lualine_c = {
      diff,
    },
    lualine_x = { diagnostics, lsp, filetype },
    lualine_y = {},
    lualine_z = { treesitter, persisting },
  },
  inactive_sections = {
    lualine_a = {
      "filename",
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {
    lualine_a = { { "tabs", mode = 1 } },
    lualine_b = {},
    lualine_c = { location },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
})

-- TODO: Fix intitialization of location on startup
-- TODO: Find better separation between tabs and location

-- Force more frequent tabline redraw
vim.api.nvim_create_autocmd({ "CursorMoved", "BufWinEnter", "BufFilePost", "InsertEnter", "BufWritePost" }, {
  group = vim.api.nvim_create_augroup("tabline", { clear = true }),
  command = ":redrawtabline",
})
