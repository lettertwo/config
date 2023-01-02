local highlights = {
  CmpItemKindText = true,
  CmpItemKindKeyword = true,
  CmpItemKindVariable = true,
  CmpItemKindConstant = true,
  CmpItemKindReference = true,
  CmpItemKindValue = true,
  CmpItemKindFunction = true,
  CmpItemKindMethod = true,
  CmpItemKindConstructor = true,
  CmpItemKindClass = true,
  CmpItemKindInterface = true,
  CmpItemKindStruct = true,
  CmpItemKindEvent = true,
  CmpItemKindEnum = true,
  CmpItemKindUnit = true,
  CmpItemKindModule = true,
  CmpItemKindProperty = true,
  CmpItemKindField = true,
  CmpItemKindTypeParameter = true,
  CmpItemKindEnumMember = true,
  CmpItemKindOperator = true,
  CmpItemKindSnippet = true,
}

local function capcase(str)
  return str:sub(1, 1):upper() .. str:sub(2)
end

local function format_highlight(str, group)
  return "%#" .. group .. "#" .. str .. "%*"
end

local function highlight(icon, kind)
  local group = "CmpItemKind" .. capcase(kind)
  if not highlights[group] then
    group = "CmpItemKindText"
  end
  return format_highlight(icon, group)
end

local separator = highlight("  ", "Snippet")

local icons = {
  File = highlight(" ", "File"),
  Module = highlight(" ", "Module"),
  Namespace = highlight(" ", "Namespace"),
  Package = highlight(" ", "Package"),
  Class = highlight(" ", "Class"),
  Method = highlight(" ", "Method"),
  Property = highlight(" ", "Property"),
  Field = highlight(" ", "Field"),
  Constructor = highlight(" ", "Constructor"),
  Enum = highlight("練", "Enum"),
  Interface = highlight("練", "Interface"),
  Function = highlight(" ", "Function"),
  Variable = highlight(" ", "Variable"),
  Constant = highlight(" ", "Constant"),
  String = highlight(" ", "String"),
  Number = highlight(" ", "Number"),
  Boolean = highlight("◩ ", "Boolean"),
  Array = highlight(" ", "Array"),
  Object = highlight(" ", "Object"),
  Key = highlight(" ", "Key"),
  Null = highlight("ﳠ ", "Null"),
  EnumMember = highlight(" ", "EnumMember"),
  Struct = highlight(" ", "Struct"),
  Event = highlight(" ", "Event"),
  Operator = highlight(" ", "Operator"),
  TypeParameter = highlight(" ", "TypeParameter"),

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
    local file_icon, file_icon_color =
    require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })

    local hl_group = "FileIconColor" .. extension

    vim.api.nvim_set_hl(0, hl_group, { fg = file_icon_color })
    if isempty(file_icon) then
      file_icon = " "
      file_icon_color = " "
    end

    return " " .. format_highlight(file_icon, hl_group) .. " " .. highlight(filename, "Text")
  end
end

local function excludes()
  if vim.tbl_contains(vim.g.ui_filetypes, vim.bo.filetype) then
    vim.opt_local.winbar = nil
    return true
  end
  return false
end

return {
  {
    "SmiteshP/nvim-navic",
    event = "VeryLazy",
    config = function()
      require("nvim-navic").setup({
        icons = icons,
        separator = separator,
        highlight = false,
      })
    end,
  },
  {
    "SmiteshP/nvim-gps",
    event = "VeryLazy",
    config = function()
      require("nvim-gps").setup({
        separator = separator,
        icons = {
          ["class-name"] = icons.Class,
          ["function-name"] = icons.Function,
          ["method-name"] = icons.Method,
          ["mapping-name"] = icons.Object,
          ["sequence-name"] = icons.Array,
          ["null-name"] = icons.Null,
          ["boolean-name"] = icons.Boolean,
          ["integer-name"] = icons.Number,
          ["float-name"] = icons.Number,
          ["string-name"] = icons.String,
          ["array-name"] = icons.Array,
          ["object-name"] = icons.Object,
          ["number-name"] = icons.Number,
          ["table-name"] = icons.Object,
          ["inline-table-name"] = icons.Object,
          ["module-name"] = icons.Module,
          ["tag-name"] = highlight("炙", "Reference"),
          ["date-name"] = highlight(" ", "Text"),
          ["date-time-name"] = highlight(" ", "Text"),
          ["time-name"] = highlight(" ", "Text"),
          ["title-name"] = highlight("# ", "Reference"),
          ["label-name"] = highlight(" ", "Reference"),
          ["container-name"] = highlight(" ", "Object"),
        },
      })
    end,
  },

  -- Status bar, Tab bar, location --
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function()
      local gps = require("nvim-gps")
      local navic = require("nvim-navic")
      local noice = require("noice")

      local window_width_limit = 70

      local function is_available()
        return not excludes() and (navic.is_available() or gps.is_available())
      end

      -- TODO: Implement symbol cache.
      -- See https://github.com/glepnir/lspsaga.nvim/blob/main/lua/lspsaga/symbolwinbar.lua
      local function get_location()
        if excludes() then
          return
        end

        local location = ""

        if navic.is_available() then
          local status_ok, navic_data = pcall(navic.get_data)
          if status_ok then
            for i, data in ipairs(navic_data) do
              location = location .. data.icon .. highlight(data.name, "Text")
              if i < #navic_data then
                location = location .. separator
              end
            end
          end
        elseif gps.is_available() then
          local status_ok, gps_data = pcall(gps.get_data)
          if status_ok then
            for i, data in ipairs(gps_data) do
              location = location .. data.icon .. highlight(data.text, "Text")
              if i < #gps_data then
                location = location .. separator
              end
            end
          end
        end

        if not isempty(location) and get_buf_option("mod") then
          location = location .. " " .. format_highlight("", "diffChanged")
        end

        return isempty(location) and nil or location
      end

      local function visible_for_width(limit)
        limit = limit == nil and window_width_limit or limit
        return vim.fn.winwidth(0) > limit
      end

      local function visible_for_filetype()
        return not vim.tbl_contains(vim.g.ui_filetypes, vim.bo.filetype)
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
        get_location,
        cond = function()
          return is_available() and visible_for_filetype()
        end,
      }

      local get_mode = require("lualine.utils.mode").get_mode

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
          return get_mode()
        end,
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

      local lazy = {
        require("lazy.status").updates,
        cond = require("lazy.status").has_updates,
      }

      -- Adapted from https://github.com/LunarVim/LunarVim/blob/48320e/lua/lvim/core/lualine/components.lua#L82
      local services = {
        function()
          local buf_clients = vim.lsp.get_active_clients()
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
          lualine_a = {
            tabs,
            mode,
            noice and {
              noice.api.status.mode.get,
              cond = noice.api.status.mode.has,
            } or nil,
          },
          lualine_b = { branch },
          lualine_c = {},
          lualine_x = { diff, diagnostics },
          lualine_y = {},
          lualine_z = { services, lazy },
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
    end,
  },
}
