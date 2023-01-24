local M = {}

local Util = require("util")

M.autoformat = true

function M.toggle()
  M.autoformat = not M.autoformat
  if M.autoformat then
    Util.info("Enabled format on save", { title = "Format" })
  else
    Util.info("Disabled format on save", { title = "Format" })
  end
end

function M.format()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local have_nls = #require("null-ls.sources").get_available(ft, "NULL_LS_FORMATTING") > 0

  vim.lsp.buf.format({
    bufnr = bufnr,
    filter = function(client)
      if have_nls then
        return client.name == "null-ls"
      end
      return client.name ~= "null-ls"
    end,
  })
end

function M.on_attach(client, bufnr)
  if client.supports_method("textDocument/formatting") then
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("LspFormat" .. bufnr, {}),
      buffer = bufnr,
      callback = function()
        if M.autoformat then
          M.format()
        end
      end,
    })
    vim.api.nvim_buf_create_user_command(bufnr, "Format", M.format, { nargs = 0, desc = "Format the current buffer" })
  end
end

return M
