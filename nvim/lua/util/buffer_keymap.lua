local Keys = require("lazy.core.handler.keys")

---@class BufferKeymapUtil
local BufferKeymapUtil = {}

---@class BufferKeySpec: LazyKeys
---@field requires? string Only if the given module is loaded.

---@class BufferKeyCtx
---@field buffer number

---@class BufferKeyOpts: table

---@param spec BufferKeySpec
---@param ctx BufferKeyCtx
---@return boolean
local function default_filter(spec, ctx)
  if spec.requires and not package.loaded[spec.requires] then
    return false
  end
  return true
end

---@param spec BufferKeySpec
---@param ctx BufferKeyCtx
---@return BufferKeyOpts
local function default_get_opts(spec, ctx)
  local opts = Keys.opts(spec)
  opts.requires = nil
  opts.silent = true
  opts.buffer = ctx.buffer
  return opts
end

---@param specs BufferKeySpec[]
---@param ctx BufferKeyCtx
---@param filter fun(spec: BufferKeySpec, ctx: BufferKeyCtx): boolean
---@param get_opts fun(spec: BufferKeySpec, ctx: BufferKeyCtx): BufferKeyOpts
---@return fun(): BufferKeySpec | nil, BufferKeyOpts | nil
local function iterate_parsed_keymap_specs(specs, ctx, filter, get_opts)
  local co = coroutine.create(function()
    for _, spec in ipairs(specs) do
      local parsed = Keys.parse(spec) --[[@as BufferKeySpec]]
      if filter == nil or filter(parsed, ctx) then
        coroutine.yield(parsed, get_opts(parsed, ctx))
      end
    end
  end)

  return function()
    local status, spec, opts = coroutine.resume(co)
    if status then
      return spec, opts
    end
  end
end

---@class BufferKeymapDescriptor
---@field keys? BufferKeySpec[]
---@field filter? fun(spec: BufferKeySpec, ctx: BufferKeyCtx): boolean
---@field get_opts? fun(opts: table, spec: BufferKeySpec, ctx: BufferKeyCtx): BufferKeyOpts

---@param desc BufferKeymapDescriptor
function BufferKeymapUtil.create_buffer_keymap(desc)
  local keys = desc.keys

  ---@class BufferKeymap
  local M = {
    keys = desc.keys,
  }

  function M.filter(spec, ctx)
    if default_filter(spec, ctx) then
      if desc.filter then
        return desc.filter(spec, ctx)
      else
        return true
      end
    end
    return false
  end

  function M.get_opts(spec, ctx)
    local opts = default_get_opts(spec, ctx)
    if desc.get_opts then
      return desc.get_opts(opts, spec, ctx)
    else
      return opts
    end
  end

  ---@param ctx BufferKeyCtx | integer
  ---@param specs? BufferKeySpec[]
  function M.apply(ctx, specs)
    if type(ctx) == "number" then
      ctx = { buffer = ctx }
    else
      ctx = vim.tbl_extend("force", { buffer = vim.api.nvim_get_current_buf() }, ctx)
    end
    if desc.keys ~= nil then
      for parsed, opts in iterate_parsed_keymap_specs(desc.keys, ctx, M.filter, M.get_opts) do
        vim.keymap.set(parsed.mode or "n", parsed[1], parsed[2], opts)
      end
    end

    if specs ~= nil then
      for parsed, opts in iterate_parsed_keymap_specs(specs, ctx, M.filter, M.get_opts) do
        vim.keymap.set(parsed.mode or "n", parsed[1], parsed[2], opts)
      end
    end
  end

  return M
end

return BufferKeymapUtil
