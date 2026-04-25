---@class Config.PackUtil
local PackUtil = {}

---@class Config.PackUtil.UpdateState
---@field pending boolean true while a check is in flight
---@field count integer? nil = never checked; number = updates available
---@field last_checked integer? vim.uv.now() of last completion

---@type Config.PackUtil.UpdateState
local update_state = { pending = false, count = nil, last_checked = nil }

local function emit_updates_changed()
	vim.api.nvim_exec_autocmds("User", {
		pattern = "PackUpdatesChanged",
		data = vim.deepcopy(update_state),
	})
end

--- Returns the cached update state. Does not trigger a check.
---@return Config.PackUtil.UpdateState
function PackUtil.get_update_state()
	return update_state
end

--- Resets the cached update state so the next check_updates() runs fresh.
function PackUtil.reset_update_state()
	update_state.count = nil
	update_state.last_checked = nil
	emit_updates_changed()
end

--- Asynchronously checks each managed plugin for upstream updates via
--- `git ls-remote`. Idempotent: no-op if a check is already in flight.
--- Fires the `PackUpdatesChanged` User autocmd when the state changes.
---
--- Note: only handles spec.version == nil (default branch) and string
--- (branch/tag). vim.VersionRange specs are skipped (not used in cvim
--- currently). Revisit when adding a statusline component that needs
--- periodic checking in long-lived sessions.
function PackUtil.check_updates()
	if update_state.pending then
		return
	end

	update_state.pending = true
	emit_updates_changed()

	local plugins = vim.pack.get()
	local update_count = 0
	local remaining = #plugins

	local function finish_one()
		remaining = remaining - 1
		if remaining < 1 then
			update_state.count = update_count
			update_state.pending = false
			update_state.last_checked = vim.uv.now()
			emit_updates_changed()
		end
	end

	if remaining == 0 then
		update_state.count = 0
		update_state.pending = false
		update_state.last_checked = vim.uv.now()
		emit_updates_changed()
		return
	end

	for _, plugin in ipairs(plugins) do
		local version = plugin.spec.version
		local ref
		if version == nil then
			ref = "HEAD"
		elseif type(version) == "string" then
			ref = version
		end
		-- vim.VersionRange: skip; resolving requires listing remote tags.

		if ref == nil then
			finish_one()
		else
			vim.system(
				{ "git", "ls-remote", "--quiet", "origin", ref },
				{ cwd = plugin.path, text = true },
				vim.schedule_wrap(function(out)
					if out.code == 0 and out.stdout then
						local target_rev = out.stdout:match("^(%x+)")
						if target_rev and target_rev ~= plugin.rev then
							update_count = update_count + 1
						end
					end
					finish_one()
				end)
			)
		end
	end
end

-- Reset cached update state after vim.pack applies updates.
vim.api.nvim_create_autocmd("PackChanged", {
	callback = PackUtil.reset_update_state,
})

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
