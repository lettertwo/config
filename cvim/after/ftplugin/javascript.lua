vim.b.minisurround_config = {
  custom_surroundings = {
    s = {
      input = { "%[%[().-()%]%]" },
      output = { left = "```", right = "```" },
    },
    ["*"] = {
      input = { "%/%*% ?().-()% ?%*%/" },
      output = { left = "/* ", right = " */" },
    },
  },
}

Config.add("nvim-lua/plenary.nvim")
Config.add("pmizio/typescript-tools.nvim")

require("typescript-tools").setup({
  settings = {
    expose_as_code_action = "all",
    tsserver_path = vim.fn.getcwd() .. "/node_modules/.bin/tsserver",
    tsserver_max_memory = 8192,
    tsserver_file_preferences = {
      includeInlayParameterNameHints = false,
      includeInlayParameterNameHintsWhenArgumentMatchesName = false,
      includeInlayFunctionParameterTypeHints = false,
      includeInlayVariableTypeHints = false,
      includeInlayVariableTypeHintsWhenTypeMatchesName = false,
      includeInlayPropertyDeclarationTypeHints = false,
      includeInlayFunctionLikeReturnTypeHints = false,
      includeInlayEnumMemberValueHints = false,
    },
    -- tsserver_format_options = {},
  },

  handlers = {
    ["textDocument/publishDiagnostics"] = require("typescript-tools.api").filter_diagnostics(
      -- Ignore 'This may be converted to an async function' diagnostics.
      { 80006 }
    ),
  },
})
