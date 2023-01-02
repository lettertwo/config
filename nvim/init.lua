if require("first_run")() then
  return
end

require("config.settings")
require("config.commands")
require("config.autocommands")
require("plugins")

if vim.g.CONFIG_LOADED then
  print("Config reloaded!")
end
vim.g.CONFIG_LOADED = true
