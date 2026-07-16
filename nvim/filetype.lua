vim.filetype.add({
  extension = {
    mdx = "markdown.mdx",
  },
  pattern = {
    ["%.eslintrc.*%.json"] = "jsonc",
    ["%.parcelrc.*"] = "jsonc",
    ["tsconfig.*%.json"] = "jsonc",
    [".*/%.vscode/.*%.json"] = "jsonc",
  },
})
