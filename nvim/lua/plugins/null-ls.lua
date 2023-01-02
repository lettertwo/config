local null_ls = require("null-ls")

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins
local code_actions = null_ls.builtins.code_actions
local completion = null_ls.builtins.completion
local diagnostics = null_ls.builtins.diagnostics
local formatting = null_ls.builtins.formatting
local hover = null_ls.builtins.hover

null_ls.setup({
  debug = false,
  sources = {
    formatting.prettierd.with({
      extra_filetypes = { "toml", "flowtype", "flowtypereact" },
    }),
    formatting.black.with({ extrargs = { "fast" } }),
    formatting.stylua,
    formatting.google_java_format,
    diagnostics.flake8,
    code_actions.gitsigns,
    code_actions.gitrebase,
    completion.spell,
    hover.dictionary,
  },
})

require("mason-null-ls").setup({
  automatic_installation = true,
})
