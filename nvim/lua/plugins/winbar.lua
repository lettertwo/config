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

-- TODO: add exception for DAP windows; maybe look at the included extension,
-- or otherwise figure out a way to conditionally configure filename.
local filepath_inactive = {
  "filename",
  file_status = true,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
}

-- TODO: Implement dropbar-native version of the first lualine winbar segment
local path = {
  get_symbols = function(buf, win, _)
    local bar = require("dropbar.bar")
    local devicons = require("nvim-web-devicons")

    local symbols = {} ---@type dropbar_symbol_t[]

    local current_path = vim.fn.fnamemodify((vim.api.nvim_buf_get_name(buf)), ":p")
    if current_path == nil then
      vim.notify("filename is empty", vim.log.levels.ERROR, { title = "dropbar.nvim" })
      return symbols
    end
    current_path = vim.fs.normalize(current_path)

    local icon, icon_hl = devicons.get_icon(current_path, vim.fn.fnamemodify(current_path, ":e"), { default = true })

    local symbols = {
      bar.dropbar_symbol_t:new({
        buf = buf,
        win = win,
        icon = " " .. icon .. " ",
        icon_hl = "lualine_a_normal",
        name_hl = "lualine_a_normal",
        name = vim.fs.basename(current_path),
        -- on_click = function(self)
        --   vim.notify("Have you smiled today? " .. self.icon)
        -- end,
      }),
      -- bar.dropbar_symbol_t:new({
      --   buf = buf,
      --   win = win,
      --   icon = icon .. "",
      --   icon_hl = "lualine_a_normal",
      --   -- on_click = function(self)
      --   --   vim.notify("Have you smiled today? " .. self.icon)
      --   -- end,
      -- }),
    }

    -- if vim.bo[buf].mod then
    --   symbols[#symbols] = configs.opts.sources.path.modified(symbols[#symbols])
    -- end

    return symbols
  end,
}

-- TODO: Create two dropbar sources, one for the current path and one for the current lsp/treesitter
-- the idea is to recreate the current lualine config that has { filetype, filename } in one section
-- and { breadcrumbs } in another, and they are visually separated.
return {
  {
    "Bekaboo/dropbar.nvim",
    event = "VeryLazy",
    opts = {
      general = {
        enable = false,
      },
      icons = {
        ui = {
          bar = {
            separator = icons.separator,
          },
        },
        kinds = {
          symbols = icons,
        },
      },
      bar = {
        padding = { left = 0, right = 0 },
        truncate = false,
        sources = function(buf, _)
          local sources = require("dropbar.sources")
          local utils = require("dropbar.utils")

          if vim.bo[buf].ft == "markdown" then
            return {
              -- path,
              utils.source.fallback({
                sources.treesitter,
                sources.markdown,
                sources.lsp,
              }),
            }
          end
          return {
            -- path,
            utils.source.fallback({
              sources.lsp,
              sources.treesitter,
            }),
          }
        end,
      },
      -- menu = {
      --   win_configs = {
      --     border = "single",
      --   },
      -- },
      sources = {
        path = {
          relative_to = function(bufno)
            -- get dirname of current buffer
            return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufno), ":p:h")
          end,
        },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      local breadcrumbs = {
        function()
          if excludes() then
            return
          end

          -- TODO: update opts.menu.win_configs.col to match the size of the filepath section.
          -- from https://github.com/Bekaboo/dropbar.nvim/issues/19#issuecomment-1574760272
          return "%{%v:lua.dropbar.get_dropbar_str()%}"
        end,
        cond = function()
          return visible_for_filetype()
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
