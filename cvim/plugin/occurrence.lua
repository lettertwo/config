local cwd = vim.loop.cwd()
local is_plugin_dir = cwd ~= nil
  and cwd:find("occurrence.nvim", 1, true) ~= nil
	and vim.fs.find({ "occurrence.lua" }, { type = "file", path = "./lua" })[1] ~= nil

if cwd ~= nil and is_plugin_dir then
	Config.link("lettertwo/occurrence.nvim", cwd)
	require("occurrence.dev").setup()
else
	Config.once("BufReadPost", function()
		Config.add("lettertwo/occurrence.nvim")
		require("occurrence").setup()
	end)
end
