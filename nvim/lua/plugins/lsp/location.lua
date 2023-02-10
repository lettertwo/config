local M = {}

function M.on_attach(client, bufnr)
  local navic_ok, navic = pcall(require, "nvim-navic")
  if navic_ok and navic and client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end
end

return M
