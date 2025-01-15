#!/usr/bin/env -S LUA_PATH=${XDG_CONFIG_HOME}/task/?.lua\_${XDG_CONFIG_HOME}/task/lua

local client = require("task_client"):new()
local uuids = client:fetch_expired_daily_tasks({ uuids = true })
if #uuids > 0 then
	io.stderr:write(string.format("Found %d expired daily tasks\n", #uuids))
	client:delete(unpack(uuids))
end
