local gps = require("nvim-gps")
local navic = require("nvim-navic")

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
}

navic.setup({
  icons = icons,
  separator = separator,
  highlight = false,
})

gps.setup({
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

local location_exclude = {
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

    return " " .. format_highlight(file_icon, hl_group) .. " " .. highlight(filename, "Text")
  end
end

local function excludes()
  if vim.tbl_contains(location_exclude, vim.bo.filetype) then
    vim.opt_local.winbar = nil
    return true
  end
  return false
end

local function is_available()
  return not excludes() and (navic.is_available() or gps.is_available())
end

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

  return location
end

return { get_location = get_location, is_available = is_available }
