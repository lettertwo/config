---@class Config.Stats
---@field nvim { version: string, commit: string }
---@field plugin { count: integer, loaded: integer }
---@field startuptime integer
local ConfigStats = setmetatable({}, {
	__index = function(self, key)
		if Config._stats ~= nil and Config._stats[key] ~= nil then
			return Config._stats[key]
		elseif key == "nvim" then
			local version, commit = unpack(vim.split(vim.fn.execute("version"):gsub(".*%sv([%w%p]+)\n.*", "%1"), "+"))
			Config._stats = Config._stats or {}
			Config._stats.nvim = { version = version, commit = commit and commit:sub(1, 7) or "" }
			return Config._stats.nvim
		elseif key == "plugin" then
			local plugins = vim.pack.get()
			Config._stats = Config._stats or {}
			Config._stats.plugin = { loaded = 0, count = 0 }
			for _, spec in ipairs(vim.pack.get()) do
				Config._stats.plugin.count = Config._stats.plugin.count + 1
				if spec.active then
					Config._stats.plugin.loaded = Config._stats.plugin.loaded + 1
				end
			end
			return Config._stats.plugin
		elseif key == "startuptime" then
			return -1
		else
			return rawget(self, key)
		end
	end,
})

return ConfigStats
