local function pack(...)
	if table.pack then
		return table.pack(...)
	else
		return { n = select("#", ...), ... }
	end
end

---@class TaskClientArgs
---@field protected args string[]
local TaskClientArgs = {
	args = {},
}

---@return TaskClientArgs
---@param ... string
function TaskClientArgs:new(...)
	local o = { args = {} }
	setmetatable(o, { __index = self })
	return o:append(...)
end

---@param query string
function TaskClientArgs:parse(query)
	local args = {}
	for arg in string.gmatch(query, "%S+") do
		table.insert(args, arg)
	end
	return TaskClientArgs:new(unpack(args))
end

---@param ... string
---@return TaskClientArgs
function TaskClientArgs:append(...)
	local args = pack(...)
	for i = 1, args.n do
		table.insert(self.args, args[i])
	end
	return self
end

---@param ... string
---@return TaskClientArgs
function TaskClientArgs:prepend(...)
	local args = pack(...)
	for i = args.n, 1, -1 do
		table.insert(self.args, 1, args[i])
	end
	return self
end

---@param ... string
---@return TaskClientArgs
function TaskClientArgs:remove(...)
	local args = pack(...)
	for i = 1, args.n do
		for j = #self.args, 1, -1 do
			if self.args[j] == args[i] then
				table.remove(self.args, j)
			end
		end
	end
	return self
end

---@return string
function TaskClientArgs:prepare()
	return table.concat(TaskClientArgs.args, " ") .. " " .. table.concat(self.args, " ")
end

return TaskClientArgs
