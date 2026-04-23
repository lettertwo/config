---@class Config.EventUtil
local EventUtil = {}

local CONFIG_GROUP = vim.api.nvim_create_augroup("Config", { clear = true })

---@alias Event vim.api.create_autocmd.callback.args
---@alias EventHandler fun(event: Event): boolean?

-- Create an autocommand that triggers on the specified event(s) and pattern(s).
---@param event string|string[] Autocommand event(s) to listen for.
---@param pattern string|string[] Optional pattern(s) to match.
---@param callback EventHandler Function to call when the event is triggered.
---@param desc string? Optional description for the autocommand.
---@overload fun(event: string|string[], callback: EventHandler, desc: string?): integer
function EventUtil.on(event, pattern, callback, desc)
	---@type vim.api.keyset.create_autocmd.opts
	local opts = { group = CONFIG_GROUP }
	if type(pattern) == "function" then
		opts.callback = pattern
		---@cast callback -function+string?
		opts.desc = callback
	else
		opts.pattern = pattern
		opts.callback = callback
		opts.desc = desc
	end
	return vim.api.nvim_create_autocmd(event, opts)
end

-- Like `Config.on()`, but the autocommand will be removed after the first time it's triggered.
---@param event string|string[] Autocommand event(s) to listen for.
---@param pattern string|string[]? Optional pattern(s) to match.
---@param callback EventHandler Function to call when the event is triggered.
---@param desc string? Optional description for the autocommand.
---@overload fun(event: string|string[], callback: EventHandler, desc: string?): integer
function EventUtil.once(event, pattern, callback, desc)
	---@type vim.api.keyset.create_autocmd.opts
	local opts = { group = CONFIG_GROUP, once = true }
	if type(pattern) == "function" then
		opts.callback = pattern
		---@cast callback -function+string?
		opts.desc = callback
	else
		opts.pattern = pattern
		opts.callback = callback
		opts.desc = desc
	end
	return vim.api.nvim_create_autocmd(event, opts)
end

-- Remove autocommands by ID or by event and pattern.
---@param id_or_event number|string Autocommand ID or event name to remove.
---@param pattern string? Optional pattern to further filter autocommands when removing by event.
function EventUtil.off(id_or_event, pattern)
	if type(id_or_event) == "number" then
		return vim.api.nvim_del_autocmd(id_or_event)
	end
	for _, cmd in ipairs(vim.api.nvim_get_autocmds({ group = CONFIG_GROUP, event = id_or_event, pattern = pattern })) do
		vim.api.nvim_del_autocmd(cmd.id)
	end
end

return EventUtil
