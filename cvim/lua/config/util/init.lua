local EventUtil = require("config.util.event")
local PackUtil = require("config.util.pack")
local RootUtil = require("config.util.root")
local SessionUtil = require("config.util.session")
local StatusUtil = require("config.util.status")
local StringUtil = require("config.util.string")

---@class Config.Util: Config.EventUtil, Config.PackUtil, Config.RootUtil, Config.SessionUtil, Config.StatusUtil, Config.StringUtil
local ConfigUtil = {}

return vim.tbl_extend("error", ConfigUtil, EventUtil, PackUtil, RootUtil, SessionUtil, StatusUtil, StringUtil)
