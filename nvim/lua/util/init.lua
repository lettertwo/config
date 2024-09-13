-- Adapted from: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/util/init.lua

---@class ConfigUtil: LazyUtilCore, BufferKeymapUtil, HoverUtil, LspUtil, MasonUtil, RootUtil, ServiceUtil, StringUtil, ToggleUtil
local ConfigUtil = vim.tbl_extend(
  "error",
  require("lazy.core.util"),
  require("util.buffer_keymap"),
  require("util.hover"),
  require("util.lsp"),
  require("util.mason"),
  require("util.root"),
  require("util.service"),
  require("util.string"),
  require("util.toggle")
)

---@param plugin string
function ConfigUtil.has(plugin)
  return require("lazy.core.config").plugins[plugin] ~= nil
end

---@param name string
function ConfigUtil.opts(name)
  local plugin = require("lazy.core.config").plugins[name]
  if not plugin then
    return {}
  end
  local Plugin = require("lazy.core.plugin")
  return Plugin.values(plugin, "opts", false)
end

function ConfigUtil.config_path()
  local config = vim.fn.stdpath("config") or "~/.config/nvim"
  if type(config) == "table" then
    config = config[1]
  end
  return config
end

---@param str string
function ConfigUtil.termcodes(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

---@param keys string
---@param mode? string
function ConfigUtil.feedkeys(keys, mode)
  if mode == nil then
    mode = "in"
  end
  return vim.api.nvim_feedkeys(ConfigUtil.termcodes(keys), mode, true)
end

--- Gets the buffer number of every visible buffer
--- @return integer[]
function ConfigUtil.visible_buffers()
  return vim.tbl_map(vim.api.nvim_win_get_buf, vim.api.nvim_list_wins())
end

function ConfigUtil.close_floats()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
      vim.api.nvim_win_close(win, false)
    end
  end
end

function ConfigUtil.clear_highlights()
  vim.cmd("nohlsearch")
  if ConfigUtil.lsp_active() then
    vim.lsp.buf.clear_references()
    for _, buffer in pairs(ConfigUtil.visible_buffers()) do
      vim.lsp.util.buf_clear_references(buffer)
    end
  end
end

function ConfigUtil.close_floats_and_clear_highlights()
  ConfigUtil.close_floats()
  if vim.bo.modifiable then
    ConfigUtil.clear_highlights()
  else
    if #vim.api.nvim_list_wins() > 1 then
      return ConfigUtil.feedkeys("<C-w>c")
    end
  end
end

function ConfigUtil.debounce(ms, fn)
  local timer = vim.uv.new_timer()
  local argv
  return function(...)
    argv = { ... }
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(unpack(argv))
    end)
  end
end

function ConfigUtil.interval(ms, fn)
  local timer = vim.uv.new_timer()
  timer:start(ms, ms, fn)
  return function()
    timer:stop()
    timer:close()
  end
end

---@param bufnr integer
---@param force? boolean
function ConfigUtil.delete_buffer(bufnr, force)
  if force == nil then
    force = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "terminal"
  end
  local bufremove_ok, bufremove = pcall(require, "mini.bufremove")
  if bufremove_ok and bufremove then
    local ok, success = pcall(bufremove.delete, bufnr, force)
    return ok and success
  else
    local ok = pcall(vim.api.nvim_buf_delete, bufnr, { force = force })
    return ok
  end
end

function ConfigUtil.is_callable(callback)
  if type(callback) == "function" then
    return true
  end
  local cb_meta = getmetatable(callback)
  if cb_meta ~= nil then
    return ConfigUtil.is_callable(cb_meta.__call)
  end
  return false
end

return ConfigUtil
