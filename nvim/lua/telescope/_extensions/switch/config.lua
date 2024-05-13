--- @class SwitchOptions
---@field sort_lastused boolean
---@field ignore_current boolean
---@field sort_mru boolean
---@field sort_tags ?function
---@field select_current boolean

local config_options = {
  sort_mru = false,
  ignore_current = true,
  sort_lastused = false,
}

---@class SwitchConfig
---@overload fun(options: SwitchOptions): nil
local M = {}

--- Get the configuration for switch
---@param extra_opts SwitchOptions?
---@return SwitchOptions
function M.get(extra_opts)
  return vim.tbl_extend("force", config_options, extra_opts or {})
end

--- Set the configuration for switch
---@param options SwitchOptions
function M.set(options)
  for k, v in pairs(options) do
    config_options[k] = v
  end
end

---@diagnostic disable-next-line: param-type-mismatch
setmetatable(M, {
  __call = function(self, ext_config)
    self.set(ext_config)
  end,
})

return M
