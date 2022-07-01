local Log = require("lvim.core.log")

---@usage Select which servers should be configured manually. Requires `:LvimCacheReset` to take effect.
local servers = {
  "flow",
  tsserver = {
    -- Only activate tsserver if the project has config for it.
    root_dir = require("lspconfig").util.root_pattern("tsconfig.json", "jsconfig.json"),
  },
  "sumneko_lua",
}

-- Exempt our manually configured servers from automatic configuration
local skipped_servers = lvim.lsp.automatic_configuration.skipped_servers
for k, v in pairs(servers) do
  if type(k) == "number" then
    k = v
  end
  if not vim.tbl_contains(skipped_servers, k) then
    Log:debug("Skipping automatic lsp config for  " .. k)
    table.insert(skipped_servers, k)
  end
end

---@usage setup a server -- see: https://www.lunarvim.org/languages/#overriding-the-default-configuration
local lsp_setup = require("lvim.lsp.manager").setup
for lsp, opts in pairs(servers) do
  if type(lsp) == "number" then
    lsp_setup(opts)
  else
    lsp_setup(lsp, opts)
  end
end

local _, navic = pcall(require, "nvim-navic")

-- -- you can set a custom on_attach function that will be used for all the language servers
-- -- See <https://github.com/neovim/nvim-lspconfig#keybindings-and-completion>
lvim.lsp.on_attach_callback = function(client, bufnr)
  if client.name == "sumneko_lua" then
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end

  if navic and client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end
end

-- filetypes that javascript-adjacent.
local js_filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact", "flowtype" }

-- set a formatter, this will override the language server formatting capabilities (if it exists)
local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup({
  { command = "stylua" },
  { command = "prettier", filetypes = js_filetypes },
})

-- set additional linters
local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
  { command = "eslint", filetypes = js_filetypes },
})

-- set additional code actions
local code_actions = require("lvim.lsp.null-ls.code_actions")
code_actions.setup({
  { command = "eslint", filetypes = js_filetypes },
  { command = "gitsigns" },
  { command = "gitrebase" },
})

-- set additional diagnostics
local services = require("lvim.lsp.null-ls.services")
services.register_sources({ command = "eslint" }, "diagnostics")
