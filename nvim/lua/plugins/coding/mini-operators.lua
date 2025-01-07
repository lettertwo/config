return {
  -- operators, evals
  {
    "echasnovski/mini.operators",
    event = "VeryLazy",
    opts = {
      evaluate = {
        prefix = "g=",
        func = nil,
      },
      exchange = {
        prefix = "gX",
        -- Whether to reindent new text to match previous indent
        reindent_linewise = true,
      },
      multiply = {
        prefix = "gm",
        func = nil,
      },
      replace = {
        prefix = "gR",
        -- Whether to reindent new text to match previous indent
        reindent_linewise = true,
      },
      sort = {
        prefix = "gS",
        func = nil,
      },
    },
  },
}
