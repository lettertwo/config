---@class HoverUtil
local HoverUtil = {}

-- A hover highlight is a table with the following fields:
-- 1. The highlight group name
-- 2. The line number (0-indexed)
-- 3. The start column (0-indexed)
-- 4. The end column (0-indexed)
---@alias HoverHighlight { [1]: string, [2]: number, [3]: number, [4]: number }

---@class HoverResult
---@field lines string[]
---@field highlights? HoverHighlight[]

---@class HoverSpec
---@field name string
---@field priority number
---@field enabled boolean | fun(): boolean
---@field execute fun(done: fun(result: HoverResult | nil): nil): nil

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

---@return HoverSpec[]
local function build_pipeline()
  local specs = {}
  for _, spec in pairs(registry) do
    if is_enabled(spec) then
      table.insert(specs, spec)
    end
  end
  table.sort(specs, function(a, b)
    return a.priority > b.priority
  end)
  return specs
end

---@param spec HoverSpec
function HoverUtil.register_hover(spec)
  if not spec.name then
    error("Hover spec must have a name")
  end

  registry[spec.name] = spec
end

---@param pipeline HoverSpec[]
---@param done fun(result: {[1]: HoverSpec, [2]: HoverResult}[] | nil)
---@param results {[1]: HoverSpec, [2]: HoverResult}[] | nil
local function next(pipeline, done, results)
  local spec = table.remove(pipeline, 1)
  if spec then
    results = results or {}
    spec.execute(function(result)
      if result then
        table.insert(results, { spec, result })
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

---@param results {[1]: HoverSpec, [2]: HoverResult}[]
---@param opts? table
local function show_hover(results, opts)
  if vim.tbl_isempty(results) then
    return
  end

  -- TODO: get default opts from vim lsp hover?
  opts = opts or {}

  local lines = {}

  ---@type HoverHighlight[]
  local highlights = {}

  for _, entry in ipairs(results) do
    local spec = entry[1]
    local result = entry[2]
    local highlight_line_offset = #lines
    if not isempty(result.lines) then
      if not isempty(lines) then
        table.insert(lines, "---")
        highlight_line_offset = highlight_line_offset + 1
      end

      table.insert(lines, "## " .. spec.name)
      highlight_line_offset = highlight_line_offset + 1

      for _, line in ipairs(result.lines) do
        table.insert(lines, line)
      end

      if not isempty(result.highlights) then
        for _, hi in ipairs(result.highlights) do
          table.insert(highlights, { hi[1], hi[2] + highlight_line_offset, hi[3], hi[4] })
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
    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(bufnr, -1, hl[1], hl[2], hl[3], hl[4])
    end
  end
end

---@param opts? table
function HoverUtil.hover(opts)
  next(build_pipeline(), function(results)
    if results then
      show_hover(results, opts)
    end
  end)
end

return HoverUtil
