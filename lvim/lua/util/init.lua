-- Adapted from: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/util/init.lua

---@class ConfigUtil: LazyUtilCore, ServiceUtil, StringUtil
local ConfigUtil = vim.tbl_extend("error", require("lazy.core.util"), require("util.service"), require("util.string"))

return ConfigUtil
