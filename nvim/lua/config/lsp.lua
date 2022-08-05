local lsp_installer = require("nvim-lsp-installer")
local lspconfig = require("lspconfig")

local servers = {
  sumneko_lua = {
    settings = {
      Lua = {
        diagnostics = {
          globals = { "vim", "packer_plugins" },
        },
        workspaces = {
          library = {
            [vim.fn.expand("$VIMRUNTIME/lua")] = true,
            [vim.fn.stdpath("config") .. "/lua"] = true,
          },
          maxPreload = 100000,
          preloadFileSize = 10000,
        },
        telemetery = {
          enabled = false,
        },
      },
    },
  },
  tsserver = {
    -- Only activate tsserver if the project has config for it.
    root_dir = lspconfig.util.root_pattern("tsconfig.json", "jsconfig.json"),
  },
  "flow",
  "html",
  "jsonls",
  "cssls",
  "pyright",
  "bashls",
  "yamlls",
}

lsp_installer.setup({
  ensure_installed = {},
  automatic_installation = true,
  ui = {
    border = "rounded",
    icons = {
      server_installed = "✓",
      server_pending = "",
      server_uninstalled = "✗",
    },
  },
})

local function lsp_keymaps(bufnr)
  local keymap = require("keymap").buffer(bufnr)
  keymap.normal.leader({
    ["."] = { ":lua vim.lsp.buf.code_action()<CR>", "Show code actions" },
    ["="] = { ":lua vim.lsp.buf.format({ async = true })<CR>", "Format document" },
    R = { ":lua vim.lsp.buf.rename()<CR>", "Rename" },
    l = {
      name = "LSP",
      f = { ":lua vim.lsp.buf.format({ async = true })<CR>", "Format document" },
      a = { ":lua vim.lsp.buf.code_action()<CR>", "Show code actions" },
      h = { ":lua vim.lsp.buf.hover()<CR>", "Show hover" },
      r = { ":lua vim.lsp.buf.rename()<CR>", "Rename" },
      s = { ":lua vim.lsp.buf.signature_help()<CR>", "Show signature help" },
      S = { ":LspInfo<CR>", "Show LSP status" },
      I = { ":LspInstallInfo<CR>", "Show LSP install info" },
    },
  })

  keymap.normal("K", ":lua vim.lsp.buf.hover()<CR>", "Show hover")
  keymap.insert("<A-K>", ":lua vim.lsp.buf.hover()<CR>", "Show hover")

  keymap.normal("<A-k>", ":lua vim.lsp.buf.signature_help()<CR>", "Show signature help")
  keymap.insert("<A-k>", ":lua vim.lsp.buf.signature_help()<CR>", "Show signature help")

  keymap.normal.register({
    gd = { ":lua vim.lsp.buf.definition()<CR>", "Go to definition" },
    gr = { ":lua vim.lsp.buf.references()<CR>", "Find references" },
    gt = { ":lua vim.lsp.buf.type_definition()<CR>", "Go to type" },
    gD = { ":lua vim.lsp.buf.declaration()<CR>", "Go to declaration" },
    gI = { ":lua vim.lsp.buf.implementation()<CR>", "Go to implementation" },
  })
end

local function on_attach(client, bufnr)
  if client.name == "tsserver" then
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end

  if client.name == "sumneko_lua" then
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end

  local _, navic = pcall(require, "nvim-navic")
  if navic and client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end

  lsp_keymaps(bufnr)
end

-- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)

local default_opts = { on_attach = on_attach, capabilities = capabilities }

for server, opts in pairs(servers) do
  if type(server) == "number" then
    server = opts
    opts = {}
  end

  lspconfig[server].setup(vim.tbl_deep_extend("error", default_opts, opts))
end

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
})
