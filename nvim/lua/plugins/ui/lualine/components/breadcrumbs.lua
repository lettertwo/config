local M = require("lualine.component"):extend()
local filetype = require("plugins.ui.lualine.components").filetype

function M:update_status()
  if package.loaded["dropbar"] then
    -- TODO: update opts.menu.win_configs.col to match the size of the filepath section.
    -- from https://github.com/Bekaboo/dropbar.nvim/issues/19#issuecomment-1574760272
    return " %{%v:lua.dropbar()%}"
  end
end

function M:draw()
  self.status = ""

  if not filetype.cond() then
    return self.status
  end
  if self.options.cond ~= nil and self.options.cond() ~= true then
    return self.status
  end

  self.status = self:update_status()

  return self.status
end

return M
