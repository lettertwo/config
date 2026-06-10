---@class Config.EventUtil
local EventUtil = {}

local CONFIG_GROUP = vim.api.nvim_create_augroup("Config", { clear = true })

---@alias Event vim.api.keyset.create_autocmd.callback_args
---@alias EventHandler fun(event: Event): boolean?

-- Create an autocommand that triggers on the specified event(s) and pattern(s) or buffer.
---@overload fun(event: string|string[], callback: EventHandler, desc: string?): integer
---@overload fun(event: string|string[], pattern: string|string[], callback: EventHandler, desc: string?): integer
---@overload fun(event: string|string[], buf: number, callback: EventHandler, desc: string?): integer
function EventUtil.on(event, pattern_or_buf_or_cb, cb_or_desc, desc)
  ---@type vim.api.keyset.create_autocmd
  local opts = { group = CONFIG_GROUP }
  if type(pattern_or_buf_or_cb) == "function" then
    opts.callback = pattern_or_buf_or_cb
    ---@cast cb_or_desc -function+string?
    opts.desc = cb_or_desc
  elseif type(pattern_or_buf_or_cb) == "number" then
    opts.buf = pattern_or_buf_or_cb
    opts.callback = cb_or_desc
    opts.desc = desc
  else
    opts.pattern = pattern_or_buf_or_cb
    opts.callback = cb_or_desc
    opts.desc = desc
  end
  return vim.api.nvim_create_autocmd(event, opts)
end

-- Like `Config.on()`, but the autocommand will be removed after the first time it's triggered.
---@overload fun(event: string|string[], callback: EventHandler, desc: string?): integer
---@overload fun(event: string|string[], pattern: string|string[], callback: EventHandler, desc: string?): integer
---@overload fun(event: string|string[], buf: number, callback: EventHandler, desc: string?): integer
function EventUtil.once(event, pattern_or_buf_or_cb, cb_or_desc, desc)
  ---@type vim.api.keyset.create_autocmd
  local opts = { group = CONFIG_GROUP, once = true }
  if type(pattern_or_buf_or_cb) == "function" then
    opts.callback = pattern_or_buf_or_cb
    ---@cast cb_or_desc -function+string?
    opts.desc = cb_or_desc
  elseif type(pattern_or_buf_or_cb) == "number" then
    opts.buf = pattern_or_buf_or_cb
    opts.callback = cb_or_desc
    opts.desc = desc
  else
    opts.pattern = pattern_or_buf_or_cb
    opts.callback = cb_or_desc
    opts.desc = desc
  end
  return vim.api.nvim_create_autocmd(event, opts)
end

-- Remove autocommands by ID or by event and pattern or buf.
---@overload fun(id: number)
---@overload fun(event: string|string[], buf: number)
---@overload fun(event: string|string[], pattern: string)
function EventUtil.off(id_or_event, pattern_or_buf)
  if type(id_or_event) == "number" then
    return vim.api.nvim_del_autocmd(id_or_event)
  elseif type(pattern_or_buf) == "number" then
    for _, cmd in ipairs(vim.api.nvim_get_autocmds({ group = CONFIG_GROUP, event = id_or_event, buf = pattern_or_buf })) do
      vim.api.nvim_del_autocmd(cmd.id)
    end
  else
    for _, cmd in
      ipairs(vim.api.nvim_get_autocmds({ group = CONFIG_GROUP, event = id_or_event, pattern = pattern_or_buf }))
    do
      vim.api.nvim_del_autocmd(cmd.id)
    end
  end
end

return EventUtil
