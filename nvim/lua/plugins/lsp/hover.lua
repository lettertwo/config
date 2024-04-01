local util = require("vim.lsp.util")

local M = {}

local function get_signature_help(params, cb)
  local lines = {}
  local highlights = {}
  local bufnr = vim.api.nvim_get_current_buf()

  vim.lsp.buf_request_all(bufnr, "textDocument/signatureHelp", params, function(responses)
    if vim.api.nvim_get_current_buf() ~= bufnr then
      -- Ignore result since buffer changed. This happens for slow language servers.
      return cb()
    end

    for client_id, response in pairs(responses) do
      if response.result and response.result.signatures then
        local client = assert(vim.lsp.get_client_by_id(client_id))
        local triggers = vim.tbl_get(client.server_capabilities, "signatureHelpProvider", "triggerCharacters")
        local ft = vim.bo[bufnr].filetype

        local line_offset = #lines
        local markdown_lines, active_hl = util.convert_signature_help_to_markdown_lines(response.result, ft, triggers)
        if markdown_lines and not vim.tbl_isempty(markdown_lines) then
          vim.list_extend(lines, markdown_lines)
          if active_hl then
            -- Highlight the second line if the signature is wrapped in a Markdown code block.
            local active_line_offset = vim.startswith(markdown_lines[1], "```") and line_offset + 1 or line_offset
            table.insert(highlights, { "LspSignatureActiveParameter", active_line_offset, unpack(active_hl) })
          end
        end
      end
    end

    lines = util.trim_empty_lines(lines)

    if not vim.tbl_isempty(lines) then
      cb({ lines = lines, highlights = highlights })
    else
      cb()
    end
  end)
end

local function get_hover(params, cb)
  local lines = {}
  local bufnr = vim.api.nvim_get_current_buf()

  vim.lsp.buf_request_all(bufnr, "textDocument/hover", params, function(responses)
    if vim.api.nvim_get_current_buf() ~= bufnr then
      -- Ignore result since buffer changed. This happens for slow language servers.
      return cb()
    end

    for _, response in pairs(responses) do
      if response.result and response.result.contents then
        local markdown_lines = util.convert_input_to_markdown_lines(response.result.contents)
        markdown_lines = util.trim_empty_lines(markdown_lines)
        if not vim.tbl_isempty(markdown_lines) then
          vim.list_extend(lines, markdown_lines)
        end
      end
    end

    lines = util.trim_empty_lines(lines)

    if not vim.tbl_isempty(lines) then
      cb({ lines = lines })
    else
      cb()
    end
  end)
end

local CALL_EXPRESSION_TYPES = {
  "call_expression",
  "function_call",
  "method_call",
  "tag_call",
  "table_call",
  "parenthesized_expression",
}

local function in_function_call()
  local ts_utils_ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
  if not ts_utils_ok then
    return false
  end
  local node = ts_utils.get_node_at_cursor()
  if node and node:parent() then
    return vim.tbl_contains(CALL_EXPRESSION_TYPES, node:parent():type())
  else
    return false
  end
end

M.config = {
  name = "LSP",
  priority = 1,
  enabled = function()
    for _, client in pairs(vim.lsp.get_clients()) do
      if
        client
        and (client.supports_method("textDocument/signatureHelp") or client.supports_method("textDocument/hover"))
      then
        return true
      end
    end
    return false
  end,
  execute = function(done)
    local params = util.make_position_params()

    -- if position is within a function call,
    -- show signature help, otherwise show hover.
    if in_function_call() then
      get_signature_help(params, done)
    else
      get_hover(params, done)
    end
  end,
}

function M.on_attach(client, _)
  if client.supports_method("textDocument/hover") then
    require("util").register_hover(M.config)
  end
end

return M
