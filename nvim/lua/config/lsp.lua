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
    l = {
      name = "LSP",
      f = { ":lua vim.lsp.buf.formatting()<CR>", "Format document" },
      a = { ":lua vim.lsp.buf.code_action()<CR>", "Show code actions" },
      r = { ":lua vim.lsp.buf.rename()<CR>", "Rename" },
      s = { ":lua vim.lsp.buf.signature_help()<CR>", "Show signature help" },
      S = { ":LspInfo<CR>", "Show LSP status" },
      I = { ":LspInstallInfo<CR>", "Show LSP install info" },
    },
  })

  keymap.normal("K", "<cmd>lua vim.lsp.buf.hover()<CR>", "Show hover")
  keymap.insert("<A-K>", "<cmd>lua vim.lsp.buf.hover()<CR>", "Show hover")

  keymap.normal("<A-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", "Show signature help")
  keymap.insert("<A-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", "Show signature help")

  local trouble_ok, _ = pcall(require, "trouble")
  if trouble_ok then
    keymap.normal.register({
      gd = { ":Trouble lsp_definitions<CR>", "Go to definition" },
      gr = { ":Trouble lsp_references<CR>", "Find references" },
    })
    keymap.normal.leader({
      l = {
        name = "LSP",
        d = { ":Trouble lsp_definitions<CR>", "Go to definition" },
        r = { ":Trouble lsp_references<CR>", "Find references" },
        t = { ":Trouble lsp_type_definitions<CR>", "Go to type" },
        D = { ":lua vim.lsp.buf.declaration()<CR>", "Go to declaration" },
        i = { ":Trouble lsp_implementations<CR>", "Go to implementation" },
      },
    })
  else
    keymap.normal.register({
      gd = { ":lua vim.lsp.buf.definition()<CR>", "Go to definition" },
      gr = { ":lua vim.lsp.buf.references()<CR>", "Find references" },
    })
    keymap.normal.leader({
      l = {
        name = "LSP",
        d = { ":lua vim.lsp.buf.definition()<CR>", "Go to definition" },
        r = { ":lua vim.lsp.buf.references()<CR>", "Find references" },
        t = { ":lua vim.lsp.buf.type_definition()<CR>", "Go to type" },
        D = { ":lua vim.lsp.buf.declaration()<CR>", "Go to declaration" },
        i = { ":lua vim.lsp.buf.implementation()<CR>", "Go to implementation" },
      },
    })
  end
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

  lsp_keymaps(bufnr)
end

local default_opts = { on_attach = on_attach }

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

require('lsp_signature').setup({
  bind = true,
  handler_opts = {
    border = "rounded",
  },
})
