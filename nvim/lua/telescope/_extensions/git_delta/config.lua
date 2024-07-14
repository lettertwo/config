--- @class GitDeltaOptions
--- @field bufnr number? Buffer number to diff. Use 0 for current buffer or nil for all buffers
--- @field pager string? Pager to use for git_delta. Default: 'less -R -P "?e ::'
local config_options = {
  pager = 'less -R -P "?e ::"',
}

---@class GitDeltaConfig
---@overload fun(options: GitDeltaOptions): nil
local M = {}

--- Get the configuration for git_delta
---@param extra_opts GitDeltaOptions?
---@return GitDeltaOptions
function M.get(extra_opts)
  return vim.tbl_extend("force", config_options, extra_opts or {})
end

--- Set the configuration for git_delta
---@param options GitDeltaOptions
function M.set(options)
  for k, v in pairs(options) do
    config_options[k] = v
  end
end

---@diagnostic disable-next-line: param-type-mismatch
setmetatable(M, {
  __call = function(self, ext_config)
    self.set(ext_config)

    -- This gets delta diffs to play nicely with <c-d>/<c-u> in telescope previewer
    -- See https://github.com/nvim-telescope/telescope.nvim/issues/605#issuecomment-1874803100
    local telescope_defaults = require("telescope.config").values
    telescope_defaults.set_env = vim.tbl_extend("force", telescope_defaults.set_env or {}, {
      LESS = "",
      DELTA_PAGER = "less",
    })
  end,
})

return M
