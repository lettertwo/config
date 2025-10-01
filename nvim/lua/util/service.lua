---@class ServiceUtil
local ServiceUtil = {}

function ServiceUtil.service_status()
  local buf = vim.api.nvim_get_current_buf()
  local buf_ft = vim.bo.filetype

  ---@class ServiceStatus
  ---@field diagnostic_providers string[]
  ---@field formatting_providers string[]
  ---@field copilot_active boolean
  ---@field treesitter_active boolean
  ---@field session_active boolean
  ---@field lazy_updates boolean
  local status = {
    diagnostic_providers = {},
    formatting_providers = {},
    copilot_active = false,
    treesitter_active = vim.treesitter.highlighter.active[buf] ~= nil
      and next(vim.treesitter.highlighter.active[buf]) ~= nil,
    session_active = package.loaded["persistence"] and require("persistence").current ~= nil,
    lazy_updates = require("lazy.status").has_updates(),
    -- TODO: check for mason updates
    -- mason_updates
  }

  -- add lsp clients
  for _, client in pairs(vim.lsp.get_clients()) do
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

  ---@class ServiceStatus
  return status
end

return ServiceUtil
