-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
vim.diagnostic.config({
  -- Show all diagnostics as underline
  underline = { min = vim.diagnostic.severity.HINT, max = vim.diagnostic.severity.ERROR },
  update_in_insert = false, -- Don't update diagnostics when typing
  -- Show virtual text only for errors on the current line
  virtual_lines = false,
  virtual_text = {
    current_line = true,
    spacing = 4,
    source = "if_many",
    prefix = "●",
    severity = { min = vim.diagnostic.severity.ERROR, max = vim.diagnostic.severity.ERROR },
  },
  severity_sort = true,
  float = { border = "rounded", source = true, header = "", prefix = "" },
  signs = {
    -- Show signs on top of any other sign, but only for warnings and errors
    priority = 9999,
    severity = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.ERROR },
    text = {
      [vim.diagnostic.severity.ERROR] = Config.icons.diagnostics.Error,
      [vim.diagnostic.severity.WARN] = Config.icons.diagnostics.Warn,
      [vim.diagnostic.severity.HINT] = Config.icons.diagnostics.Hint,
      [vim.diagnostic.severity.INFO] = Config.icons.diagnostics.Info,
    },
  },
})
