return {
  { "HiPhish/neotest-busted", lazy = true },
  { "LuaCATS/luassert", name = "luassert-types", lazy = true },
  { "LuaCATS/busted", name = "busted-types", lazy = true },
  {
    "folke/lazydev.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.library, {
        { path = "luassert-types/library", words = { "assert" } },
        { path = "busted-types/library", words = { "describe" } },
      })
    end,
  },
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        "neotest-busted",
      },
    },
  },
  {
    "folke/which-key.nvim",
    ft = "lua",
    keys = {
      --  i++ expands to i = i + 1
      { "++", " = <Esc>^yt=f=lpa+ 1", mode = "i", desc = "Increment variable" },
      -- i+= expands to i = i + <cursor>
      { "+=", " = <Esc>^yt=f=lpa+ ", mode = "i", desc = "Combine variable" },
    },
  },
}
