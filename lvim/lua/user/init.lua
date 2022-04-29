local Log = require("lvim.core.log")

local walk_modules = require("fs").walk_modules
local configpath = get_config_dir()

-- These config modules should be loaded before others.
local modules = {
	"user.plugins",
	"user.keys",
}

-- Find and load user config modules, starting with those defined in `modules`.
local function load()
	-- Load everything defined in `modules` first.
	for _, name in pairs(modules) do
		Log:debug("loading " .. name)
		require(name)
	end
	-- Discover and load other user config modules.
	for name in walk_modules(join_paths(configpath, "lua", "user")) do
		if name ~= "user" and not modules[name] then
			Log:debug("found and loaded " .. name)
			require(name)
		end
	end
end

-- Unload all user config modules.
local function unload()
	-- Also remove user config modules from impatient.nvim cache.
	local luacache = (_G.__luacache or {}).cache
	for name, _ in pairs(package.loaded) do
		if name:match("^user.") then
			package.loaded[name] = nil
			if luacache then
				luacache[name] = nil
			end
			Log:debug("unloaded " .. name)
		end
	end
end

-- Reload all user config modules.
local function reload(changed)
	unload()
	vim.cmd([[:LvimReload]])
	Log:debug("user config reloaded!")
end

return {
	load = load,
	reload = reload,
}
