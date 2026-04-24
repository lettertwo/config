---@class Config.PackUtil
local PackUtil = {}

-- Resolve plugin name to a full GitHub URL if it's in "user/repo" format.
---@param name string Plugin name, either in "user/repo" or "https://github.com/user/repo"
function PackUtil.resolve_plugin_url(name)
	if not vim.startswith(name, "https://") then
		name = "https://github.com/" .. name
	end
	return name
end

-- Extract the "repo" part of "user/repo" or a full GitHub URL.
---@param name string Plugin name, either in "user/repo" or "https://github.com/user/repo"
function PackUtil.parse_plugin_name(name)
	if vim.startswith(name, "https://") then
		name = name:match("https://github.com/(.+)")
	end
	return vim.split(name, "/")[2] or name
end

-- Add a plugin to the current session (via `vim.pack.add()`).
-- The plugin name can be specified either in "user/repo" format or as a full GitHub URL.
---@param name string Plugin name, either in "user/repo" or "https://github.com/user/repo"
function PackUtil.add(name)
	vim.pack.add({ PackUtil.resolve_plugin_url(name) })
end

-- Link a local plugin at the specified directory into the local pack directory.
-- The plugin name can be specified either in "user/repo" format or as a full GitHub URL.
---@param name string The name of the plugin to load in dev mode
---@param dir string The working directory of the plugin to load in dev mode
function PackUtil.link(name, dir)
	name = PackUtil.parse_plugin_name(name)
	vim.notify("Linking " .. name .. " from local path", vim.log.levels.DEBUG)
	local dev_name = name .. "-dev"
	local local_path = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "dev", "opt", dev_name)
	if vim.uv.fs_stat(local_path) then
		if vim.uv.fs_unlink(local_path) then
			vim.notify("Removed existing link at " .. local_path, vim.log.levels.TRACE)
		else
			vim.notify("Failed to remove existing link at " .. local_path, vim.log.levels.ERROR)
		end
	end
	-- create the parent directories for the local plugin path if they don't exist
	if vim.fn.mkdir(vim.fs.dirname(local_path), "p") then
		vim.notify("Created directories " .. vim.fs.dirname(local_path), vim.log.levels.TRACE)
	else
		vim.notify("Failed to create directories at " .. vim.fs.dirname(local_path), vim.log.levels.ERROR)
	end
	-- symlink the current directory to the local plugin path
	if vim.uv.fs_symlink(dir, local_path, { dir = true }) then
		vim.notify("Linked " .. local_path .. " to " .. dir, vim.log.levels.TRACE)
	else
		vim.notify("Failed to link " .. local_path .. " to " .. dir, vim.log.levels.ERROR)
	end

	vim.cmd.packadd(dev_name)
end

function PackUtil.show_pack_log()
	local log_file = vim.fs.joinpath(vim.fn.stdpath("log"), "nvim-pack.log")
	if vim.uv.fs_stat(log_file) then
		vim.cmd.edit(log_file)
	else
		vim.notify("No log file found at " .. log_file, vim.log.levels.WARN)
	end
end

return PackUtil
