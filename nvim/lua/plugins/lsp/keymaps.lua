local M = {}
local format = require("plugins.lsp.format").format

M.keys = {
  { "<leader>uf", require("plugins.lsp.format").toggle, desc = "Toggle format on Save" },
  { "gd", ":TroubleToggle lsp_definitions<CR>", desc = "Go to definition", requires = "trouble" },
  { "gr", ":TroubleToggle lsp_references<CR>", desc = "Find references", requires = "trouble" },
  { "gD", vim.lsp.buf.declaration, desc = "Go to declaration" },
  { "gI", ":TroubleToggle lsp_implementations<CR>", desc = "Go to implementation", requires = "trouble" },
  { "gt", ":TroubleToggle lsp_type_definitions<CR>", desc = "Go to type", requires = "trouble" },
  { "K", vim.lsp.buf.hover, desc = "Show hover" },
  { "gK", vim.lsp.buf.signature_help, desc = "Show signature help", has = "signatureHelp" },
  { "<leader>.", vim.lsp.buf.code_action, mode = { "n", "x" }, desc = "Show code actions", has = "codeAction" },
  { "<leader>=", format, desc = "Format document", has = "documentFormatting" },
  { "<leader>=", format, desc = "Format Range", mode = "x", has = "documentRangeFormatting" },
  { "<leader>R", vim.lsp.buf.rename, desc = "Rename", has = "rename" },
  { "<leader>lf", format, desc = "Format document" },
  { "<leader>la", vim.lsp.buf.code_action, desc = "Show code actions" },
  { "<leader>lh", vim.lsp.buf.hover, desc = "Show hover" },
  { "<leader>lr", vim.lsp.buf.rename, desc = "Rename" },
  { "<leader>ls", vim.lsp.buf.signature_help, desc = "Show signature help" },
  { "<leader>lS", ":LspInfo<CR>", desc = "Show LSP status", requires = "lspconfig" },
}

function M.on_attach(client, bufnr)
  local Keys = require("lazy.core.handler.keys")
  local keymaps = {}

  for _, value in ipairs(M.keys) do
    local keys = Keys.parse(value)
    keymaps[keys.id] = keys
  end

  for _, keys in pairs(keymaps) do
    if
      (not keys.requires or package.loaded[keys.requires] ~= nil)
      or (not keys.has or client.server_capabilities[keys.has .. "Provider"])
    then
      local opts = Keys.opts(keys)
      opts.has = nil
      opts.requires = nil
      opts.silent = true
      opts.buffer = bufnr
      vim.keymap.set(keys.mode or "n", keys[1], keys[2], opts)
    end
  end
end

return M
