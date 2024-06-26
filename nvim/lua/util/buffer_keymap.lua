local Keys = require("lazy.core.handler.keys")

---@class BufferKeymapUtil
local BufferKeymapUtil = {}

---@class BufferKey: LazyKeys

---@class BufferKeySpec: LazyKeysSpec
---@field requires? string Only if the given module is loaded.

---@class BufferKeyCtx
---@field buffer number

---@class BufferKeyOpts: LazyKeysBase

---@param spec BufferKeySpec
---@return boolean
local function default_filter(spec)
  if spec.requires and require("lazy.core.config").plugins[spec.requires] ~= nil then
    return false
  end
  return true
end

---@param spec BufferKey
---@param ctx BufferKeyCtx
---@return BufferKeyOpts
local function default_get_opts(spec, ctx)
  ---@class LazyKeysBase
  local opts = Keys.opts(spec)
  opts.requires = nil
  opts.silent = true
  opts.buffer = ctx.buffer
  return opts --[[@as BufferKeyOpts]]
end

---@param specs BufferKeySpec[]
---@param ctx BufferKeyCtx
---@param filter fun(spec: BufferKey, ctx: BufferKeyCtx): boolean
---@param get_opts fun(spec: BufferKey, ctx: BufferKeyCtx): BufferKeyOpts
---@return fun(): BufferKey | nil, BufferKeyOpts | nil
local function iterate_parsed_keymap_specs(specs, ctx, filter, get_opts)
  local co = coroutine.create(function()
    for _, spec in ipairs(specs) do
      local parsed = Keys.parse(spec) --[[@as BufferKey]]
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
  ---@class BufferKeymap
  local M = {
    keys = desc.keys,
    ---@type table<number, table[]>
    active_buffer_keymaps = {},
  }

  function M.filter(spec, ctx)
    if default_filter(spec) then
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

    local active_keymaps = {}

    local function apply(parsed, opts)
      local args = { parsed.mode or "n", parsed.lhs or parsed[1], parsed.rhs or parsed[2], opts }
      vim.keymap.set(unpack(args))
      table.remove(args, 3)
      table.insert(active_keymaps, args)
    end

    if desc.keys ~= nil then
      for parsed, opts in iterate_parsed_keymap_specs(desc.keys, ctx, M.filter, M.get_opts) do
        apply(parsed, opts)
      end
    end

    if specs ~= nil then
      for parsed, opts in iterate_parsed_keymap_specs(specs, ctx, M.filter, M.get_opts) do
        apply(parsed, opts)
      end
    end

    M.active_buffer_keymaps[ctx.buffer] = vim.list_extend(M.active_buffer_keymaps[ctx.buffer] or {}, active_keymaps)
  end

  ---@param ctx BufferKeyCtx | integer
  function M.clear(ctx)
    local bufnr = type(ctx) == "number" and ctx or ctx.buffer
    if not bufnr then
      bufnr = vim.api.nvim_get_current_buf()
    end

    local active_keymaps = M.active_buffer_keymaps[bufnr]
    M.active_buffer_keymaps[bufnr] = nil

    if active_keymaps then
      for _, args in ipairs(active_keymaps) do
        vim.keymap.del(unpack(args))
      end
    end
  end

  return M
end

return BufferKeymapUtil
