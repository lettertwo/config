local configpath = vim.fn.stdpath("config")
local walk_modules = require("fs").walk_modules
local join_paths = require("fs").join_paths
local module_path = join_paths(configpath, "lua")
local init_file = join_paths(configpath, "init.lua")
local group = vim.api.nvim_create_augroup('config', { clear = true }) 

local function unload_module(module_name)
  local luacache = (_G.__luacache or {}).cache -- impatient.nvim cache
  local module_name_pattern = vim.pesc(module_name)
  local function matcher(pack)
  end

  for pack, _ in pairs(package.loaded) do
    if string.find(pack, "^" .. module_name_pattern) then
      print('unloading ' .. pack)
      package.loaded[pack] = nil
      if luacache then
        luacache[pack] = nil
      end
    end
  end

end

local function reload(evt)
  for module in walk_modules(module_path) do
    unload_module(module)
  end
  vim.cmd(':luafile ' .. init_file)
  if evt.file:match("plugins.lua$") then
    vim.cmd [[ PackerSync ]]
  end
end

-- Show absolute line numbers in insert mode
vim.api.nvim_create_autocmd("InsertEnter", { group = group, pattern = { "*" }, command = ":set norelativenumber" })
vim.api.nvim_create_autocmd("InsertLeave", { group = group, pattern = { "*" }, command = ":set relativenumber" })

-- Reload config files
vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = { init_file, "*/nvim/lua/*.lua", "*/nvim/lua/*/*.lua" },
  callback = reload,
})

-- Close cmdwin with <Esc>
vim.api.nvim_create_autocmd("CmdwinEnter", {
  group = group,
  callback = function()
    require("keymap").buffer().normal("<Esc>", "<C-c><C-c>", "Exit Command")
  end,
})
