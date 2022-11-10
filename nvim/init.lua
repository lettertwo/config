if require("first_run")() then
  return
end

require("settings")
require("commands")
require("autocommands")
require("plugins")

if vim.g.CONFIG_LOADED then
  print("Config reloaded!")
end
vim.g.CONFIG_LOADED = true
