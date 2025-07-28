local M = require("lualine.component"):extend()

local icons = LazyVim.config.icons
local Util = require("util")

function M:update_status()
  -- Adapted from https://github.com/LunarVim/LunarVim/blob/48320e/lua/lvim/core/lualine/components.lua#L82
  local display = {}
  local status = Util.service_status()

  if #status.diagnostic_providers > 0 then
    table.insert(display, icons.services.diagnostics .. table.concat(status.diagnostic_providers, ", "))
  end

  -- add formatters
  if #status.formatting_providers > 0 then
    table.insert(display, icons.services.formatting)
  end

  -- add copilot
  if status.copilot_active then
    table.insert(display, icons.services.copilot)
  end

  -- add treesitter
  if status.treesitter_active then
    table.insert(display, icons.services.treesitter)
  end

  if status.session_active then
    table.insert(display, icons.services.persisting)
  else
    table.insert(display, icons.services.not_persisting)
  end

  if status.lazy_updates then
    local checker = require("lazy.manage.checker")
    table.insert(display, " " .. #checker.updated)
  end

  return table.concat(display, " ")
end

return M
