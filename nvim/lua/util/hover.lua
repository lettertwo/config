---@class HoverUtil
local HoverUtil = {}

---@class HoverHighlight
---@field hlname string
---@field prefix {hlname: string, length: number} | nil
---@field suffix {hlname: string, length: number} | nil

---@class HoverResult
---@field lines string[]
---@field highlights? HoverHighlight[]

---@class HoverSpec
---@field name string
---@field priority number
---@field enabled boolean | fun(): boolean
---@field execute fun(done: fun(result: HoverResult | nil))

---@type table<string, HoverSpec>
local registry = {}

local function isempty(lines)
  if lines == nil then
    return true
  end
  if not vim.tbl_isempty(lines) then
    for _, line in ipairs(lines) do
      if line ~= "" then
        return false
      end
    end
  end
  return true
end

local function is_callable(f)
  local tf = type(f)
  if tf == "function" then
    return true
  elseif tf == "table" then
    local mt = getmetatable(f)
    return type(mt) == "table" and type(mt.__call) == "function"
  else
    return false
  end
end

local function is_enabled(spec)
  if is_callable(spec.enabled) then
    return spec.enabled()
  else
    return spec.enabled
  end
end

---@returns fun(done: fun(result: HoverResult | nil)))[]
local function get_active_specs()
  local specs = {}
  for _, spec in pairs(registry) do
    if is_enabled(spec) then
      table.insert(specs, spec)
    end
  end
  table.sort(specs, function(a, b)
    return a.priority > b.priority
  end)
  return vim.tbl_map(function(spec)
    return spec.execute
  end, specs)
end

---@param spec HoverSpec
function HoverUtil.register(spec)
  if not spec.name then
    error("Hover spec must have a name")
  end

  registry[spec.name] = spec
end

---@param name string
function HoverUtil.has(name)
  return registry[name] ~= nil
end

---@param pipeline HoverSpec[]
---@param done fun(result: HoverResult | nil)
---@param results HoverResult[] | nil
local function next(pipeline, done, results)
  local fn = table.remove(pipeline, 1)
  if fn then
    results = results or {}
    fn(function(result)
      if result then
        table.insert(results, result)
      end
      next(pipeline, done, results)
    end)
  else
    if results == nil or vim.tbl_isempty(results) then
      done()
    else
      done(results)
    end
  end
end

---@param results HoverResult[]
---@param opts? table
local function show_hover(results, opts)
  if vim.tbl_isempty(results) then
    return
  end

  -- TODO: get default opts from vim lsp hover?
  local opts = opts or {}

  local lines = {}

  ---@type HoverHighlight[]
  local highlights = {}

  if #results == 1 then
    lines = results[1].lines
    highlights = results[1].highlights
  else
    for _, result in ipairs(results) do
      if not isempty(result.lines) then
        if not isempty(lines) then
          table.insert(lines, "---")
        end

        for _, line in ipairs(result.lines) do
          table.insert(lines, line)
        end

        if not isempty(result.highlights) then
          for _, highlight in ipairs(result.highlights) do
            table.insert(highlights, highlight)
          end
        end
      end
    end
  end

  local float_opts = vim.tbl_extend("keep", opts, {
    border = "rounded",
    focusable = true,
    focus_id = "hover",
    close_events = { "CursorMoved", "BufHidden", "InsertCharPre" },
  })

  local bufnr, _ = vim.lsp.util.open_floating_preview(lines, "markdown", float_opts)

  if highlights and not isempty(highlights) then
    for i, hl in ipairs(highlights) do
      local line = lines[i]
      local prefix_len = hl.prefix and hl.prefix.length or 0
      local suffix_len = hl.suffix and hl.suffix.length or 0
      if prefix_len > 0 then
        vim.api.nvim_buf_add_highlight(bufnr, -1, hl.prefix.hlname, i - 1, 0, prefix_len)
      end
      vim.api.nvim_buf_add_highlight(bufnr, -1, hl.hlname, i - 1, prefix_len, #line - suffix_len)
      if suffix_len > 0 then
        vim.api.nvim_buf_add_highlight(bufnr, -1, hl.suffix.hlname, i - 1, #line - suffix_len, -1)
      end
    end
  end
end

---@param opts? table
function HoverUtil.hover(opts)
  next(get_active_specs(), function(results)
    if results then
      show_hover(results, opts)
    end
  end)
end

return HoverUtil
