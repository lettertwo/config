local M = {}

function M.on_attach(client, bufnr)
  local _, navic = pcall(require, "nvim-navic")
  if navic and client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end
end

return M


