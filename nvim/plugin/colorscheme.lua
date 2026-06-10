local cwd = vim.loop.cwd()
local is_plugin_dir = cwd ~= nil
  and cwd:find("laserwave.nvim", 1, true) ~= nil
  and vim.fs.find({ "init.lua" }, { type = "file", path = "./lua/laserwave" })[1] ~= nil

if cwd ~= nil and is_plugin_dir then
  Config.link("lettertwo/laserwave.nvim", cwd)
  require("laserwave.dev").setup()
else
  Config.add("lettertwo/laserwave.nvim")
  require("laserwave").setup()
end

vim.cmd.colorscheme("laserwave")
