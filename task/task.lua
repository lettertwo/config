---@class Task
---@field uuid string
---@field protected _raw string
local Task = {}

---@param raw string
function Task.validate(raw)
	if raw == nil then
		error("Task:validate: raw is nil")
	end

	local json = require("rapidjson")
	local _, err = json.decode(raw)
	if err ~= nil then
		error("Task:validate: " .. err)
	end

	return raw
end

---@params self_or_opts Task|table
---@param opts table?
function Task.new(self_or_opts, opts)
	if opts == nil then
		opts = self_or_opts
	end

	local o = {}

	for k, v in pairs(opts) do
		o[k] = v
	end

	setmetatable(o, { __index = Task })
	return o
end

---@param raw string
function Task:from_raw(raw)
	local o = self:new()
	o._raw = self.validate(raw)
	return o
end

return Task
