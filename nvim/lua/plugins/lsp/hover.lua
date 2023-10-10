local M = {}

M.config = {
  name = "LSP",
  priority = 1,
  enabled = function()
    for _, client in pairs(vim.lsp.get_clients()) do
      if client and client.supports_method("textDocument/hover") then
        return true
      end
    end
    return false
  end,
  execute = function(done)
    local util = require("vim.lsp.util")
    local params = util.make_position_params()
    local lines = {}

    vim.lsp.buf_request_all(0, "textDocument/hover", params, function(responses)
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
        done({ lines = lines, filetype = "markdown" })
      else
        done()
      end
    end)
  end,
}

function M.on_attach(client, _)
  if client.supports_method("textDocument/hover") then
    require("util").register_hover(M.config)
  end
end

return M
