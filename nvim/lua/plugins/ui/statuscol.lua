return {
  { "folke/snacks.nvim", optional = true, opts = { statuscolumn = { enabled = false } } },
  {
    "luukvbaal/statuscol.nvim",
    event = "VeryLazy",
    opts = function()
      local builtin = require("statuscol.builtin")
      return {
        separator = " ",
        relculright = true,
        setopt = true,
        ft_ignore = LazyVim.config.filetypes.ui,
        segments = {
          -- sign
          { text = { "%s" }, click = "v:lua.ScSa" },
          -- line number
          {
            text = { builtin.lnumfunc, " " },
            condition = { true, builtin.not_empty },
            click = "v:lua.ScLa",
          },
          -- fold
          {
            text = { builtin.foldfunc, " " },
            condition = { true, builtin.not_empty },
            click = "v:lua.ScFa",
          },
        },
      }
    end,
  },
}
