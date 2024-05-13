--- @class GitJumpOptions
--- @field bufnr number? Buffer number to get hunks from. Use 0 for current buffer or nil for all buffers
local config_options = {}

---@class GitJumpConfig
---@overload fun(options: GitJumpOptions): nil
local M = {}

--- Get the configuration for git_jump
---@param extra_opts GitJumpOptions?
---@return GitJumpOptions
function M.get(extra_opts)
  return vim.tbl_extend("force", config_options, extra_opts or {})
end

--- Set the configuration for git_jump
---@param options GitJumpOptions
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
