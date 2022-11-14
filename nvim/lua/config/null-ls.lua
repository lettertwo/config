local null_ls = require("null-ls")
local h = require("null-ls.helpers")
local u = require("null-ls.utils")

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins
local code_actions = null_ls.builtins.code_actions
local completion = null_ls.builtins.completion
local diagnostics = null_ls.builtins.diagnostics
local formatting = null_ls.builtins.formatting
local hover = null_ls.builtins.hover

-- https://eslint.org/docs/user-guide/configuring/configuration-files#configuration-file-formats
local eslint_config_file_formats = {
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.yaml",
  ".eslintrc.yml",
  ".eslintrc.json",
}

local eslint_opts = {
  extra_filetypes = { "flowtype", "flowtypereact" },
  condition = function(utils)
    return utils.root_has_file(eslint_config_file_formats)
  end,
  cwd = h.cache.by_bufnr(function(params)
    return u.root_pattern(unpack(eslint_config_file_formats))(params.bufname)
  end),
}

null_ls.setup({
  debug = false,
  sources = {
    formatting.prettierd.with({
      extra_filetypes = { "toml", "flowtype", "flowtypereact" },
    }),
    formatting.black.with({ extrargs = { "fast" } }),
    formatting.stylua,
    formatting.google_java_format,
    diagnostics.eslint_d.with(eslint_opts),
    diagnostics.flake8,
    code_actions.eslint_d.with(eslint_opts),
    code_actions.gitsigns,
    code_actions.gitrebase,
    completion.spell,
    hover.dictionary,
  },
})

require("mason-null-ls").setup({
  automatic_installation = true,
})
