local configpath = vim.fn.stdpath("config")
local walk_modules = require("fs").walk_modules
local join_paths = require("fs").join_paths
local module_path = join_paths(configpath, "lua")
local init_file = join_paths(configpath, "init.lua")
local group = vim.api.nvim_create_augroup('config', { clear = true }) 

local function reload(evt)
  local luacache = (_G.__luacache or {}).cache -- impatient.nvim cache
  for module in walk_modules(module_path) do
    if package.loaded[module] ~= nil then
      print('reloading ' .. module)
      package.loaded[module] = nil
      if luacache then
        luacache[name] = nil
      end
    end
  end
  vim.cmd(':luafile ' .. init_file)
  if evt.file:match("plugins.lua$") then
    vim.cmd [[ PackerSync ]]
  end
end

-- Show absolute line numbers in insert mode
vim.api.nvim_create_autocmd("InsertEnter", { group = group, pattern = { "*" }, command = ":set norelativenumber" })
vim.api.nvim_create_autocmd("InsertLeave", { group = group, pattern = { "*" }, command = ":set relativenumber" })

-- TODO: Reload config files
vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = { init_file, "*/nvim/lua/*.lua", "*/nvim/lua/*/*.lua" },
  callback = reload,
})

