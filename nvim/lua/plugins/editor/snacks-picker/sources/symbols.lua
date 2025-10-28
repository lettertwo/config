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

---@param item snacks.picker.finder.Item
local function is_top_level_symbol(item)
  return item.parent and item.parent.root
end

---@type table<string, true | string[]>
local INCLUDED = {
  markdown = true,
  help = true,
  default = {
    "Class",
    "Constant",
    "Constructor",
    "Enum",
    "Field",
    "Function",
    "Interface",
    "Method",
    "Module",
    "Namespace",
    "Package",
    "Struct",
    "Trait",
  },
}

---@type table<string, true | string[]>
local TOP_LEVEL_ONLY = {
  default = {
    "Object",
    "Constant",
    "Variable",
    "Package",
  },
}

---@param item snacks.picker.finder.Item
---@param ctx snacks.picker.finder.ctx
local function want(item, ctx)
  local filetype = ctx.meta.filetype or "default"

  local top_level_only = TOP_LEVEL_ONLY[filetype] or TOP_LEVEL_ONLY.default
  if type(top_level_only) == "boolean" or vim.tbl_contains(top_level_only, item.kind) then
    return is_top_level_symbol(item)
  end

  local included = INCLUDED[filetype] or INCLUDED.default
  if type(included) == "boolean" or vim.tbl_contains(included, item.kind) then
    return true
  end

  return false
end

---@param item snacks.picker.finder.Item
local function get_symbol_key(item)
  local line = item.pos and item.pos[1] or 0
  local kind = item.kind
  local normalized_name = item.name or item.text
  -- strip class/module/table prefixes for better matching
  -- "Class:method" -> "method"
  -- "object.key" -> "key"
  normalized_name = normalized_name:match("[^:.]+$") or normalized_name
  return string.format("%d:%s:%s", line, kind, normalized_name)
end

-- Get the normalized symbol
---@param item snacks.picker.finder.Item
---@param ctx snacks.picker.finder.ctx
---@return snacks.picker.finder.Item | nil
local function get_normalized_symbol(item, ctx)
  if not ctx.meta.symbols then
    return nil
  end
  local key = get_symbol_key(item)
  return ctx.meta.symbols[key]
end

-- Normalize a symbol item by adding  `sort_key` and `kind` fields.
-- If this symbol has been seen before, merge this symbol item into the existing one.
---@param item snacks.picker.finder.Item
---@param ctx snacks.picker.finder.ctx
local function normalize_symbol(item, ctx)
  -- Add sortable key for position-based sorting
  -- Combine line and column into a single number: line * 10000 + column
  item.sort_key = item.pos and (item.pos[1] * 10000 + (item.pos[2] or 0)) or 0

  -- Normalize kind field - handle missing or malformed kind
  local kind = item.kind or "Unknown"
  -- Some LSP items have kind in the text field (e.g., "Function callable")
  if kind == "Unknown" and item.text and item.text:match("^%w+ ") then
    kind = item.text:match("^(%w+) ")
  end
  -- Ensure item has kind field for downstream consumers
  item.kind = kind

  local existing = get_normalized_symbol(item, ctx)

  -- This is a duplicate symbol! Use the original one instead of this one.
  if existing then
    -- If this is an LSP item and the existing is treesitter, enrich the treesitter item
    if not item.ts_kind and existing.ts_kind then
      for k, v in pairs(item) do
        existing[k] = v
      end
    end
    item = existing
  end

  local parent = item.parent
  while parent and not parent.root and not want(parent, ctx) do
    parent = parent.parent
  end

  if parent then
    item.parent = normalize_symbol(parent, ctx)
  else
    item.root = true
  end

  return item
end

---Transform that deduplicates and enriches treesitter items with LSP metadata
---@param item snacks.picker.finder.Item
---@param ctx snacks.picker.finder.ctx
---@return boolean|nil false to filter out duplicate, nil to keep
local function deduplicate_symbols(item, ctx)
  if not ctx.meta.symbols then
    return
  end
  local normalized = normalize_symbol(item, ctx)
  local existing = get_normalized_symbol(normalized, ctx)
  if existing then
    -- Filter out the duplicate
    return false
  else
    -- Mark this symbol as seen
    local key = get_symbol_key(normalized)
    ctx.meta.symbols[key] = normalized
  end
end

---@type snacks.picker.finder
local function find_symbols(opts, ctx)
  -- Track seen symbols by position, kind, and name
  ctx.meta.symbols = ctx.meta.symbols or {}
  ctx.meta.filetype = vim.bo[ctx.filter.current_buf].filetype

  local ts_symbols = require("snacks.picker.source.treesitter").symbols(
    Snacks.config.merge({ tree = true, filter = INCLUDED }, opts),
    ctx
  ) --[[ @as snacks.picker.finder.Item[] ]]

  local lsp_symbols = require("snacks.picker.source.lsp").symbols(
    Snacks.config.merge({ tree = true, filter = { default = true } }, opts),
    ctx
  ) --[[ @as snacks.picker.finder.async ]]

  ---@async
  ---@type snacks.picker.finder.async
  local function collect(cb)
    for _, item in ipairs(ts_symbols) do
      if deduplicate_symbols(item, ctx) ~= false then
        cb(item)
      end
    end

    lsp_symbols(function(item)
      if want(item, ctx) and deduplicate_symbols(item, ctx) ~= false then
        cb(item)
      end
    end)
  end
  return collect
end

symbols_sources.symbols = {
  finder = find_symbols,
  matcher = {
    sort_empty = true,
    keep_parents = true,
    on_match = function(_, item)
      local parent = item.parent
      -- HACK: make sure the top-level parent is marked as root.
      -- There are cases (maybe with treesitter?) where the root node is not marked.
      while parent and not parent.root do
        if parent.text == "root" and not parent.parent then
          parent.root = true
          break
        end
        parent = parent.parent
      end
    end,
  },
  sort = { fields = { "sort_key" } },
  format = "lsp_symbol",
  layout = {
    preset = "vscode",
    preview = "main",
    hidden = {},
    layout = {
      relative = "win",
      row = 0.2,
      col = 0.6,
      width = 0.3,
      min_width = 50,
    },
  },
  on_show = function(picker)
    disable_main_preview_winbar(picker)
    resize_list_to_fit_vertical(picker)
  end,
}

-- Jump list source configuration
-- Snacks already has a built-in jumps source, this just customizes the layout
-- Use with: Snacks.picker.jumps() or LazyVim.pick("jumps")
symbols_sources.jumps = {
  layout = {
    preset = "vscode",
    preview = "main",
    hidden = {},
    layout = {
      row = 0.2,
      width = 0.3,
      min_width = 50,
    },
  },
  on_show = disable_main_preview_winbar,
}

symbols_sources.lines = {
  layout = {
    preset = "vscode",
    preview = "main",
    hidden = {},
    layout = {
      row = 0.2,
      width = 0.3,
      min_width = 50,
    },
  },
  on_show = disable_main_preview_winbar,
}

return symbols_sources
