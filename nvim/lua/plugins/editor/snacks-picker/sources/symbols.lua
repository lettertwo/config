---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local symbols_sources = {}

---@param picker snacks.Picker
local function disable_main_preview_winbar(picker)
  -- HACK: When preview is 'main', Snacks picker will create a popup win and copy winopts from the main
  -- window, including the winbar. Lualine never renders in popup windows, so we have to manually remove
  -- the winbar from the poupup that Snacks picker creates.
  if picker.preview.main and picker.preview.win then
    picker.preview.win.opts.wo.winbar = ""
    picker.preview:refresh(picker)
  end
end

---@param picker snacks.Picker
local function resize_list_to_fit_vertical(picker)
  local debounced_resize = require("snacks.util").debounce(function()
    if picker.opts.live then
      return
    end
    -- TODO: get this from opts
    local max_height = 0.6
    local list_height = math.max(math.min(#picker:items(), vim.o.lines * max_height - 10), 2)
    for _, box in ipairs(picker.layout.opts.layout) do
      if box.win == "list" then
        if box.height ~= list_height then
          box.height = list_height
          -- HACK: this is a hack to force a recalc of the layout,
          -- but the method is private and may change in the future.
          ---@diagnostic disable-next-line: invisible
          picker.layout:update()
        end
        break
      end
    end
  end, { ms = 16 })

  picker.matcher.opts.on_match = debounced_resize
  debounced_resize()
end

symbols_sources.symbols = {
  multi = { "treesitter", "lsp_symbols" },
  -- TODO: custom formatter that gives more context to common patterns.
  -- anonymous function expressions (in lua, in JS)
  -- const function expressions (in JS)
  format = "lsp_symbol",
  tree = true,
  -- sort = { fields = { "line" } },
  -- matcher = {
  --   sort_empty = true,
  -- },
  filter = {
    default = {
      "Class",
      "Constructor",
      "Constant",
      "Enum",
      "Field",
      "Function",
      "Interface",
      "Method",
      "Module",
      "Namespace",
      "Package",
      "Property",
      "Struct",
      "Trait",
      "Variable",
    },
  },
  layout = {
    preview = "main",
    preset = "vscode",
    layout = {
      row = 0.2,
      width = 0.3,
      min_width = 50,
    },
  },
  on_show = function(picker)
    disable_main_preview_winbar(picker)
    resize_list_to_fit_vertical(picker)
  end,
  transform = function(item, ctx)
    if item.source_id == 1 and item.text == "root" then
      return false
      -- ctx.meta.root = ctx.meta.root or item
      -- elseif item.source_id == 2 and item.text == "" then
      --   ctx.meta.root = ctx.meta.root or item
    end

    if ctx.meta.root then
      vim.print(vim.inspect(ctx.meta.root))
      return false
    end

    --   ctx.meta.done = ctx.meta.done or {} ---@type table<number, table<string, table<string, boolean>>>
    --   local kind, name, line = item.kind, item.name, item.pos[1]
    --
    --   if not kind or not name or not line then
    --     return false
    --   end
    --
    --   item.line = line
    --
    --   kind = kind:lower()
    --
    --   local kinds = ctx.meta.done[line]
    --
    --   if not kinds or not kinds[kind] then
    --     kinds = {}
    --     kinds[kind] = {}
    --     kinds[kind][name] = item
    --     ctx.meta.done[line] = kinds
    --   else
    --     local names = kinds[kind]
    --     for n in pairs(names) do
    --       -- if names end the same, assume its the same symbol.
    --       if name:find(n .. "$") or n:find(name .. "$") then
    --         local original_item = names[n]
    --         -- prefer details of non-ts items over ts items.
    --         if item.ts_kind == nil then
    --           for k, v in pairs(item) do
    --             original_item[k] = v
    --           end
    --         end
    --         return false
    --       end
    --     end
    --   end
  end,
}

-- TODO: source that acts like symbols source but for jumps.
-- could bind on C-o/C-i and C-n/C-p to work like bufjump.
-- source.bufjump

symbols_sources.lines = {
  on_show = disable_main_preview_winbar,
}

return symbols_sources
