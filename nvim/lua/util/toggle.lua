---@class ToggleUtil
local ToggleUtil = {}

--- Create a toggle function for an option or variable.
--- By default, the scope is assumed to be a buffer-local variable (`b`),
---
--- An optional function may be provided to handle the toggle.
--- If the handle returns `false`, the toggle will be cancelled.
---
---@param name string
---@param scope? string
---|'bo'  # buffer-local option
---|'b'   # buffer-local variable
---|'wo'  # window-local option
---|'w'   # window-local variable
---|'o'   # global option
---|'g'   # global variable
---@param handle? fun(value: boolean): false | nil
function ToggleUtil.create_toggle(name, scope, handle)
  scope = scope or "b"
  return function()
    local value = vim[scope][name]
    if value == nil then
      value = false
    else
      value = not value
    end

    if handle == nil or handle(value) ~= false then
      vim[scope][name] = value
      if value then
        require("util").info("Enabled " .. name, { title = scope })
      else
        require("util").warn("Disabled " .. name, { title = scope })
      end
    end
  end
end

return ToggleUtil
