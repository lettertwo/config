---@class TaskClient
---@field cmd string
local TaskClient = {
	cmd = "task",
}

function TaskClient:new()
	local o = {}
	setmetatable(o, { __index = self })
	return o
end

---@param args TaskClientArgs
---@param config? TaskRCOverrides
function TaskClient:prepare_cmd(args, config)
	if config == nil then
		config = require("task_rc"):new()
	end
	local cmd = self.cmd .. " " .. config:prepare() .. args:prepare()
	return cmd
end

---@param args TaskClientArgs
---@param config? TaskRCOverrides
function TaskClient:execute(args, config)
	local cmd = self:prepare_cmd(args, config)
	os.execute(cmd)
end

function TaskClient:delete(...)
	local args = require("task_client_args"):new():append(...):remove("delete"):append("delete")
	local config = require("task_rc"):new()
	self:execute(args, config)
end

---@param args TaskClientArgs
---@param report? string
---@return string[]
function TaskClient:uuids(args, report)
	args:remove("uuids"):append("uuids")
	if report then
		args:remove(report):append(report)
	end
	local cmd = self:prepare_cmd(args)
	local handle = assert(io.popen(cmd))
	local uuids = {}
	local raw = handle:read("*a")
	handle:close()
	for uuid in string.gmatch(raw, "[^%s]+") do
		table.insert(uuids, uuid)
	end
	return uuids
end

---@param args TaskClientArgs
---@return string[]
function TaskClient:lines(args)
	local cmd = self:prepare_cmd(args)
	local handle = assert(io.popen(cmd))
	local lines = {}
	for line in handle:lines() do
		line = line:gsub("^%s*(.-)%s*$", "%1")
		if line ~= "" then
			table.insert(lines, line)
		end
	end
	handle:close()
	return lines
end

---@param args TaskClientArgs
function TaskClient:raw(args)
	local cmd = self:prepare_cmd(args)
	local handle = assert(io.popen(cmd))
	local raw = handle:read("*a")
	handle:close()
	return raw
end

---@param args TaskClientArgs
---@param report? string
---@return Task[]
function TaskClient:export(args, report)
	local Task = require("task")
	args:remove("export"):append("export")
	if report then
		args:remove(report):append(report)
	end
	local cmd = self:prepare_cmd(args)
	-- print(cmd)
	local handle = assert(io.popen(cmd))

	---@type Task[]
	local tasks = {}

	local raw = handle:read("*a")
	handle:close()

	local parsed = require("rapidjson").decode(raw)
	if parsed == nil then
		return tasks
	end

	for _, v in ipairs(parsed) do
		table.insert(tasks, Task:new(v))
	end
	return tasks
end

---@param opts {uuids: boolean?}?
function TaskClient:fetch_completed_recurring_tasks(opts)
	local args = require("task_client_args"):new()
	args:append("due.before:now", "+CHILD", "+COMPLETED")
	if opts and opts.uuids then
		return self:uuids(args)
	end
	return self:export(args)
end

---@param opts {uuids: boolean?}?
function TaskClient:fetch_expired_daily_tasks(opts)
	local args = require("task_client_args"):new()
	args:append("recur:day", "+CHILD", "+OVERDUE")
	if opts and opts.uuids then
		return self:uuids(args)
	end
	return self:export(args)
end

---@param opts {uuids: boolean?}?
function TaskClient:fetch_expired_weekly_tasks(opts)
	local args = require("task_client_args"):new()
	args:append("recur:week", "+CHILD", "+OVERDUE")
	if opts and opts.uuids then
		return self:uuids(args)
	end
	return self:export(args)
end

---@param opts {uuids: boolean?}?
function TaskClient:fetch_expired_recurring_tasks(opts)
	local args = require("task_client_args"):new()
	args:append("recur", "+CHILD", "+OVERDUE")
	if opts and opts.uuids then
		return self:uuids(args)
	end
	return self:export(args)
end

---@param opts {uuids: boolean?}?
function TaskClient:fetch_recurring_tasks(opts)
	local args = require("task_client_args"):new()
	args:append("due.before:now", "+CHILD")
	if opts and opts.uuids then
		return self:uuids(args)
	end
	return self:export(args)
end

function TaskClient:hide_recurring_tasks()
	local Args = require("task_client_args")
	local tasks = self:export(Args:new("due.after:tomorrow", "+CHILD", 'wait:""'))
	local results = {}
	if #tasks then
		local date = require("date")
		for _, task in ipairs(tasks) do
			local uuid = task.uuid
			local due_date = date(task.due):fmt("%Y-%m-%d")
			self:execute(Args:new():append("modify", string.format("wait:%s", due_date), uuid))
			table.insert(results, uuid)
		end
	end
	return results
end

---@param query string
---@param opts {uuids: boolean?}?
function TaskClient:search_tasks(query, opts)
	local args = require("task_client_args"):parse(query)
	if opts and opts.uuids then
		return self:uuids(args)
	end
	return self:export(args)
end

---@param opts {raw: boolean?}?
function TaskClient:list_projects(opts)
	local args = require("task_client_args"):parse("_unique project")
	if opts and opts.raw then
		return self:raw(args)
	end
	return self:lines(args)
end

---@param opts {limit: number?, uuids: boolean?}?
function TaskClient:fetch_next_tasks(opts)
	local args = require("task_client_args"):new()
	if opts and opts.limit then
		args:append("limit:" .. opts.limit)
	end
	if opts and opts.uuids then
		return self:uuids(args, "next")
	end
	return self:export(args, "next")
end

---@param uuid string
function TaskClient:fetch_task(uuid)
	local args = require("task_client_args"):new():append(uuid)
	local result = self:export(args)
	if #result == 1 then
		return result[1]
	end
	return nil
end

return TaskClient
