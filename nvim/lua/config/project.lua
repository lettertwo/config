require("project_nvim").setup({
  detection_methods = { "pattern", "lsp" },
  patterns = { ".git", ".hg", ".bzr", ".svn" },
  show_hidden = true,
  silent_chdir = false,
})
