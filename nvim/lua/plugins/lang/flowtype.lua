LazyVim.on_very_lazy(function()
  vim.print("Loading flowtype filetype configuration")
  local function is_flowtype()
    ---@diagnostic disable-next-line: undefined-field
    return vim.fn.getline(1):match("//%s*@flow")
  end

  vim.filetype.add({
    extension = {
      flow = "flowtype",
      js = function()
        if is_flowtype() then
          return "flowtype"
        end
        return "javascript"
      end,

      jsx = function()
        if is_flowtype() then
          return "flowtypereact"
        end
        return "javascriptreact"
      end,
    },
  })
end)

return {
  {
    "nvim-treesitter/nvim-treesitter",
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      ensure_installed = { "tsx" },
    },
    ---@param opts TSConfig
    config = function(_, opts)
      -- Associate the flowtype filetypes with the typescript parser.
      vim.treesitter.language.register("tsx", "flowtypereact")
      vim.treesitter.language.register("tsx", "flowtype")
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
