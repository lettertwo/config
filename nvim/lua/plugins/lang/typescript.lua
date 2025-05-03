return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        vtsls = {
          enabled = false,
        },
        eslint = {
          cmd_env = { NODE_OPTIONS = "--max-old-space-size=8192" },
        },
      },
    },
  },
  {
    "pmizio/typescript-tools.nvim",
    ft = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    cond = vim.g.mergetool ~= true,
    config = function()
      local api = require("typescript-tools.api")
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
          ["textDocument/publishDiagnostics"] = api.filter_diagnostics(
            -- Ignore 'This may be converted to an async function' diagnostics.
            { 80006 }
          ),
        },
      })
    end,
  },
  {
    "dmmulroy/ts-error-translator.nvim",
    ft = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
    config = true,
  },
}
