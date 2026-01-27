local M = require("lualine.component"):extend()

function M:update_status()
  local multicursor_ok, multicursor = pcall(require, "multicursor-nvim")
  if multicursor_ok and multicursor.hasCursors() then
    local text = "MULTI " .. multicursor.numCursors()
    return text
  end

  return require("lualine.utils.mode").get_mode()
end

return M
