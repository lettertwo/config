#!/usr/bin/env -S LUA_PATH=${XDG_CONFIG_HOME}/task/?.lua\_${XDG_CONFIG_HOME}/task/lua

local client = require("task_client"):new()
local uuids = client:hide_recurring_tasks()
if #uuids > 0 then
	io.stderr:write(string.format("Hid %d future recurring tasks\n", #uuids))
end
