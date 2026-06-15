vim.filetype.add({
  pattern = {
    ["%.eslintrc.*%.json"] = "jsonc",
    ["%.parcelrc.*"] = "jsonc",
    ["tsconfig.*%.json"] = "jsonc",
    [".*/%.vscode/.*%.json"] = "jsonc",
  },
})
