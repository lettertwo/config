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
    formatting.prettier.with { extra_filetypes = { "toml", "flowtype" } },
    formatting.black.with { extrargs = { "fast" } },
    formatting.stylua,
    formatting.google_java_format,
    diagnostics.eslint.with { extra_filetypes = { "flowtype" } },
    diagnostics.flake8,
    code_actions.eslint.with { extra_filetypes = { "flowtype" } },
    code_actions.gitsigns,
    code_actions.gitrebase,
    completion.spell,
    hover.dictionary,
  },
})
