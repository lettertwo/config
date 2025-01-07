return {
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = "BufReadPost",
    opts = {
      keywords = {
        -- highlighting for rust todo/unimplemented macros
        -- From https://github.com/folke/todo-comments.nvim/issues/186#issuecomment-1592342384
        TODO = { alt = { "todo", "unimplemented" } },
        -- highlighting for alternative takes on hacky comments
        HACK = { alt = { "hacky", "Hacky" } },
      },
      highlight = {
        pattern = {
          [[.*<(KEYWORDS).*:]],
          -- pattern to match rust todo/unimplemented macros
          [[.*<(KEYWORDS)\s*!\(]],
        },
        comments_only = false,
      },
      search = {
        pattern = [[\b(KEYWORDS)(.*:|\s*!\()]],
      },
    },
    -- stylua: ignore
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous todo comment" },
      { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "Todo" },
      { "<leader>st", "<cmd>TodoTelescope<cr>", desc = "Todo" },
      { "<leader>sT", false },
    },
  },
}
