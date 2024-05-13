--- @class GrepOptions
--- @field prompt_title string? The title of the prompt
--- @field cwd string? The current working directory
--- @field word boolean? If true, search for the word under the cursor
--- @field search_dirs string[]? Limit search to these paths only

local config_options = {
  prompt_title = "Grep",
}

---@class GrepConfig
---@overload fun(options: GrepOptions): nil
local M = {}

--- Get the configuration for grep
---@param extra_opts GrepOptions?
---@return GrepOptions
function M.get(extra_opts)
  return vim.tbl_extend("force", config_options, extra_opts or {})
end

--- Set the configuration for grep
---@param options GrepOptions
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
