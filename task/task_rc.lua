---@class TaskRCOverrides
--
-- The verbosity level can be set to one of the following values:
-- - 0: No feedback (default)
-- - 1: Minimal feedback
-- - 2: Extensive feedback
---@field verbose? 0 | 1 | 2
--
-- When this number or greater of tasks are modified in a single command,
-- confirmation will be required, regardless of the value of confirmation variable.
-- The special value `0` is treated as an infinity. (default: `0`)
---@bfield bulk? number
--
-- Wehether to suppress all confirmation prompts.
-- Note that this has no direct analog in taskrc.
-- If `true`, the configuration as defined in taskrc will be used.
-- If `false`, actions that might normally prompt are handled in the following ways:
-- - prompts for deleting a task are treated as a 'yes'
-- - prompts for performing an undo command are treated as a 'yes'
-- - prompts for propagating changes to a recurring task are treated as a 'no'
-- (default: `false`)
---@field interactive? boolean
--
-- If `false`, all hooks are disabled.
-- (default: `false`)
---@field hooks? boolean
local TaskRCOverrides = {}

---@type TaskRCOverrides
local DefaultTaskRCOverrides = {
	verbose = 0,
	bulk = 0,
	hooks = false,
	interactive = false,
}

setmetatable(TaskRCOverrides, { __index = DefaultTaskRCOverrides })

---@return TaskRCOverrides
function TaskRCOverrides:new()
	local o = {}
	setmetatable(o, { __index = self })
	return o
end

---@return string
function TaskRCOverrides:prepare()
	local overrides = {
		string.format("rc.hooks=%d", self.hooks and 1 or 0),
		string.format("rc.bulk=%d", self.bulk),
	}

	if self.verbose == 0 then
		table.insert(overrides, "rc.verbose=nothing")
	else
		table.insert(overrides, string.format("rc.verbose=%d", self.verbose - 1))
	end

	if self.interactive == false then
		table.insert(overrides, "rc.confirmation=0")
		table.insert(overrides, "rc.recurrence.confirmation=0")
	end

	return table.concat(overrides, " ")
end

return TaskRCOverrides --[[@as TaskRCOverrides]]
