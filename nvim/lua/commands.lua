local join_paths = require("fs").join_paths
local walk_modules = require("fs").walk_modules

local configpath = vim.fn.stdpath("config")
local module_path = join_paths(configpath, "lua")
local init_file = join_paths(configpath, "init.lua")

local M = {}

local function create(name, cmd, opts)
  vim.api.nvim_create_user_command(name, cmd, opts)
  M[name] = cmd
end

local function delete(name)
  vim.api.nvim_del_user_command(name)
  M[name] = nil
end

M.create = create
M.delete = delete

local function unload_module(module_name)
  if module_name.args then
    module_name = module_name.args
  end
  ---@diagnostic disable-next-line: undefined-field
  local luacache = (_G.__luacache or {}).cache -- impatient.nvim cache
  local module_name_pattern = vim.pesc(module_name)
  for pack, _ in pairs(package.loaded) do
    if string.find(pack, "^" .. module_name_pattern) then
      print("unloading " .. pack)
      package.loaded[pack] = nil
      if luacache then
        luacache[pack] = nil
      end
    end
  end
end

create("UnloadModule", unload_module, {
  nargs = 1,
  desc = "Unload a lua module",
  complete = function()
    return vim.tbl_keys(package.loaded)
  end,
})

local function reload_config(sync_plugins)
  if type(sync_plugins) == "table" and sync_plugins.args then
    sync_plugins = sync_plugins.args == "true"
  end
  for module in walk_modules(module_path) do
    unload_module(module)
  end
  vim.cmd(":luafile " .. init_file)
  if sync_plugins == true then
    vim.cmd([[ PackerSync ]])
  end
end

create("ReloadConfig", reload_config, {
  nargs = "?",
  desc = "Reload config files",
})

return M
