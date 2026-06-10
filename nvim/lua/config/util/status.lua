---@class Config.StatusUtil
local StatusUtil = {}

---@class Config.ServiceStatus
---@field copilot_active boolean
---@field debug_active boolean
---@field diagnostic_providers string[]
---@field formatting_providers string[]
---@field pack_updates number
---@field session_active boolean
---@field treesitter_active boolean

---@return Config.ServiceStatus
function StatusUtil.service_status()
  local buf = vim.api.nvim_get_current_buf()
  local buf_ft = vim.bo.filetype

  local status = {
    copilot_active = false,
    debug_active = false, -- TODO: Debug status
    diagnostic_providers = {},
    formatting_providers = {},
    pack_updates = Config.get_update_state().count or 0,
    session_active = Config.get_active_session() ~= nil,
    treesitter_active = vim.treesitter.highlighter.active[buf] ~= nil
      and next(vim.treesitter.highlighter.active[buf]) ~= nil,
  }

  -- add lsp clients
  for _, client in pairs(vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })) do
    if client.name == "copilot" then
      status.copilot_active = true
    else
      table.insert(status.diagnostic_providers, client.name)
    end
  end

  -- add linters
  local lint_ok, lint = pcall(require, "lint")
  if lint_ok then
    local active = lint._resolve_linter_by_ft(buf_ft)
    if active then
      -- concat the active linters to the list of diagnostic providers
      for _, linter in pairs(active) do
        table.insert(status.diagnostic_providers, linter)
      end
    end
  end

  -- add formatters
  local conform_ok, conform = pcall(require, "conform")
  if conform_ok then
    local active = conform.list_formatters(buf)
    if active then
      for _, formatter in ipairs(active) do
        table.insert(status.formatting_providers, formatter)
      end
    end
    local _, lsp = conform.list_formatters_to_run(buf)
    if lsp then
      table.insert(status.formatting_providers, "lsp")
    end
  end

  return status
end

return StatusUtil

-- local status = {
--   diagnostic_providers = {},
--   formatting_providers = {},
--   copilot_active = false,
--   debug_active = package.loaded["dap"] and require("dap").status() ~= "",
--   lazy_updates = require("lazy.status").has_updates(),
--   -- TODO: check for mason updates
--   -- mason_updates
-- }
--
-- -- add lsp clients
-- for _, client in pairs(vim.lsp.get_clients()) do
--   if client.name == "copilot" then
--     status.copilot_active = true
--   else
--     table.insert(status.diagnostic_providers, client.name)
--   end
-- end
--
-- -- add linters
-- local lint_ok, lint = pcall(require, "lint")
-- if lint_ok then
--   local active = lint._resolve_linter_by_ft(buf_ft)
--   if active then
--     -- concat the active linters to the list of diagnostic providers
--     for _, linter in pairs(active) do
--       table.insert(status.diagnostic_providers, linter)
--     end
--   end
-- end
--
-- -- add formatters
-- local conform_ok, conform = pcall(require, "conform")
-- if conform_ok then
--   local active = conform.list_formatters(buf)
--   if active then
--     for _, formatter in ipairs(active) do
--       table.insert(status.formatting_providers, formatter)
--     end
--   end
--   local _, lsp = conform.list_formatters_to_run(buf)
--   if lsp then
--     table.insert(status.formatting_providers, "lsp")
--   end
-- end
--
-- ---@class ServiceStatus
-- return status
