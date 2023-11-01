---@class Config

local config = {
  ---@class Filetypes
  filetypes = {
    ui = {
      "NvimTree",
      "Outline",
      "PlenaryTestPopup",
      "TelescopePrompt",
      "Trouble",
      "alpha",
      "cmp_menu",
      "dashboard",
      "fugitive",
      "help",
      "lazy",
      "lspinfo",
      "man",
      "mason",
      "neo-tree",
      "neo-tree-popup",
      "neogitstatus",
      "neotest-output-panel",
      "neotest-summary",
      "notify",
      "noice",
      "packer",
      "qf",
      "spectre_panel",
      "startify",
      "startuptime",
      "terminal",
      "toggleterm",
      "tsplayground",
      "unite",
      "WhichKey",
    },
  },
  highlights = {
    Class = "CmpItemKindClass",
    Constant = "CmpItemKindConstant",
    Constructor = "CmpItemKindConstructor",
    Container = "CmpItemKindObject",
    Enum = "CmpItemKindEnum",
    EnumMember = "CmpItemKindEnumMember",
    Event = "CmpItemKindEvent",
    Field = "CmpItemKindField",
    Function = "CmpItemKindFunction",
    Interface = "CmpItemKindInterface",
    Keyword = "CmpItemKindKeyword",
    Label = "CmpItemKindReference",
    Method = "CmpItemKindMethod",
    Module = "CmpItemKindModule",
    Operator = "CmpItemKindOperator",
    Property = "CmpItemKindProperty",
    Reference = "CmpItemKindReference",
    Snippet = "CmpItemKindSnippet",
    Struct = "CmpItemKindStruct",
    Tag = "CmpItemKindReference",
    Text = "CmpItemKindText",
    Title = "CmpItemKindReference",
    TypeParameter = "CmpItemKindTypeParameter",
    Unit = "CmpItemKindUnit",
    Value = "CmpItemKindValue",
    Variable = "CmpItemKindVariable",
  },
  ---@class Icons
  icons = {
    separator = "  ",
    dots = "󰇘",
    prompt = "  ",
    caret = " ",
    multi = " ",
    fold = {
      foldclose = "",
      foldopen = "",
      fold = " ",
      foldsep = " ",
    },
    eob = " ",

    dap = {
      Stopped = "󰁕 ",
      Breakpoint = " ",
      BreakpointCondition = " ",
      BreakpointRejected = " ",
      LogPoint = ".>",
    },

    diagnostics = {
      Error = " ",
      Warn = " ",
      Hint = " ",
      Info = " ",
    },
    diff = {
      added = " ",
      modified = " ",
      removed = " ",
    },
    git = {
      added = " ",
      modified = " ",
      removed = " ",
      renamed = " ",
      untracked = " ",
      ignored = "",
      unstaged = "",
      staged = " ",
      conflict = " ",
    },
    services = {
      copilot = " ",
      diagnostics = " ",
      formatting = " ",
      not_persisting = " ",
      persisting = " ",
      treesitter = " ",
    },
    kinds = {
      Array = " ",
      Boolean = "󰨙 ",
      Class = " ",
      Color = " ",
      Constant = "󰏿 ",
      Constructor = " ",
      Container = " ",
      Date = " ",
      DateTime = " ",
      Enum = " ",
      EnumMember = " ",
      Event = " ",
      Field = "[] ",
      File = " ",
      Folder = " ",
      Function = "󰊕 ",
      Interface = " ",
      Key = " ",
      Keyword = " ",
      Label = " ",
      Method = "󰊕 ",
      Module = " ",
      Namespace = " ",
      Null = "ﳠ ",
      Number = " ",
      Object = " ",
      Operator = " ",
      Package = " ",
      Property = " ",
      Reference = " ",
      Snippet = " ",
      String = " ",
      Struct = " ",
      Tag = "炙",
      Text = " ",
      Time = " ",
      Title = "# ",
      TypeParameter = " ",
      Unit = " ",
      Value = " ",
      Variable = " ",
    },
  },
}

local capcase = require("util").capcase
local format_highlight = require("util").format_highlight

local function highlight_icons(icons, highlighted)
  for kind, icon in pairs(icons) do
    if type(icon) == "table" then
      highlighted[kind] = highlight_icons(icon, {})
    else
      local group = config.highlights[kind] or config.highlights[capcase(kind)] or config.highlights.Text
      highlighted[kind] = format_highlight(icon, group)
    end
  end
  return highlighted
end

---@type Icons
config.icons.highlighted = highlight_icons(config.icons, {})

return config
