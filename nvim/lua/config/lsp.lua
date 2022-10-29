local lspconfig = require("lspconfig")
local cmd = require("commands")
local autocmd = require("autocommands")
local rt = require("rust-tools")

require("mason-lspconfig").setup({ automatic_installation = true })

local servers = {
  sumneko_lua = {
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
          path = vim.split(package.path, ";"),
        },
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
  flow = {
    filetypes = { "javascript", "javascriptreact", "javascript.jsx", "flowtype", "flowtypereact" },
  },
  "html",
  "jsonls",
  "cssls",
  "pyright",
  "bashls",
  "yamlls",
}

local function lsp_keymaps(_, bufnr)
  local keymap = require("keymap").buffer(bufnr)
  keymap.normal.leader({

    ["."] = { vim.lsp.buf.code_action, "Show code actions" },
    ["="] = { vim.lsp.buf.format, "Format document" },
    R = { vim.lsp.buf.rename, "Rename" },
    l = {
      name = "LSP",
      f = { vim.lsp.buf.format, "Format document" },
      a = { vim.lsp.buf.code_action, "Show code actions" },
      h = { vim.lsp.buf.hover, "Show hover" },
      r = { vim.lsp.buf.rename, "Rename" },
      s = { vim.lsp.buf.signature_help, "Show signature help" },
      S = { ":LspInfo<CR>", "Show LSP status" },
      I = { ":LspInstallInfo<CR>", "Show LSP install info" },
    },
  })

  keymap.normal("K", vim.lsp.buf.hover, "Show hover")

  keymap.normal.register({
    gd = { ":TroubleToggle lsp_definitions<CR>", "Go to definition" },
    gr = { ":TroubleToggle lsp_references<CR>", "Find references" },
    gt = { ":TroubleToggle lsp_type_definitions<CR>", "Go to type" },
    gI = { ":TroubleToggle lsp_implementations<CR>", "Go to implementation" },
  })
end

-- A list of enabled formatters.
-- Right now, we just have 'null-ls' enabled.
-- Maybe someday we'll actually want an LSP server to do formatting.
local FORMATTERS = {
  "null-ls",
}

-- Whether to allow the given LSP client to format a buffer.
-- This is intended to be used as the filter for `vim.lsp.buf.format({filter = format_enabled})`.
---@param client table
---@return boolean
local function format_enabled(client)
  return vim.tbl_contains(FORMATTERS, client.name)
end

-- Format the given buffer using any registered LSP formatter.
---@param bufnr? number
local function format(bufnr)
  if type(bufnr) == "table" then
    bufnr = bufnr.args or nil
  end
  if type(bufnr) == "string" then
    local ok, result = pcall(tonumber, bufnr)
    bufnr = ok and result or nil
  end
  vim.lsp.buf.format({ bufnr = vim.F.if_nil(bufnr, 0), filter = format_enabled })
end

cmd.create("Format", format, { nargs = 0, desc = "Format the current buffer" })

local LSP_FORMATTING = vim.api.nvim_create_augroup("LspFormatting", {})

local function lsp_formatting(_, bufnr)
  vim.api.nvim_clear_autocmds({ group = LSP_FORMATTING, buffer = bufnr })
  autocmd.create("BufWritePre", { group = LSP_FORMATTING, buffer = bufnr, callback = format })
end

local function lsp_location(client, bufnr)
  local _, navic = pcall(require, "nvim-navic")
  if navic and client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end
end

local function on_attach(client, bufnr)
  lsp_location(client, bufnr)
  lsp_formatting(client, bufnr)
  lsp_keymaps(client, bufnr)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local default_opts = { on_attach = on_attach, capabilities = capabilities }

for server, opts in pairs(servers) do
  if type(server) == "number" then
    server = opts
    opts = {}
  end

  lspconfig[server].setup(vim.tbl_deep_extend("error", default_opts, opts))
end

-- Rust tools setup
rt.setup({
  server = {
    on_attach = function(client, bufnr)
      on_attach(client, bufnr)
      -- Hover actions
      vim.keymap.set("n", "K", rt.hover_actions.hover_actions, { buffer = bufnr })
    end,
    checkOnSave = {
      allFeatures = true,
      overrideCommand = {
        "cargo",
        "clippy",
        "--workspace",
        "--message-format=json",
        "--all-targets",
        "--all-features",
      },
    },
  },
})

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
})
