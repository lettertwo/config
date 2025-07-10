LazyVim.on_very_lazy(function()
  vim.filetype.add({
    pattern = {
      ["%.eslintrc.*%.json"] = "jsonc",
      ["%.atlaspackrc.*"] = "jsonc",
      ["%.parcelrc.*"] = "jsonc",
      ["tsconfig.*%.json"] = "jsonc",
      [".*/%.vscode/.*%.json"] = "jsonc",
    },
  })
end)

return {
  {
    "nvim-treesitter/nvim-treesitter",
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      ensure_installed = { "json5" },
    },
  },
}
