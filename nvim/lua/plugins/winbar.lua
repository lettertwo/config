local icons = require("config").icons
local filetypes = require("config").filetypes

local get_ft_icon = function(buf)
  local devicons = require("nvim-web-devicons")
  local current_path = vim.fs.normalize(
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.fn.fnamemodify((vim.api.nvim_buf_get_name(buf)), ":p")
  )
  return devicons.get_icon(current_path, vim.fn.fnamemodify(current_path, ":e"), { default = true })
end

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

-- TODO: Make filename include disambiguation if there are multiple buffers with the same name.
local filename = { "filename" }

local filetype = {
  function()
    if excludes() then
      return
    end

    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    local icon = get_ft_icon(buf)

    if vim.w[win].sticky_win ~= nil then
      icon = "󰐃 " .. icon
    end

    return icon
  end,
  cond = visible_for_filetype,
}

-- TODO: add exception for DAP windows; maybe look at the included extension,
-- or otherwise figure out a way to conditionally configure filename.
local filepath_inactive = {
  "filename",
  file_status = true,
  path = 3, -- 3: Absolute path, with tilde as the home directory
  shorting_target = 20, -- Shortens path to leave 40 spaces in the window for other components.
}

local breadcrumbs = {
  function()
    if excludes() then
      return
    end

    -- TODO: update opts.menu.win_configs.col to match the size of the filepath section.
    -- from https://github.com/Bekaboo/dropbar.nvim/issues/19#issuecomment-1574760272
    return "%{%v:lua.dropbar.get_dropbar_str()%}"
  end,
  cond = visible_for_filetype,
}

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
  -- TODO: Look into a mini-files like version of nvim-navbuddy
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      return vim.tbl_extend("force", opts, {
        winbar = {
          lualine_a = { filetype, filename },
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
