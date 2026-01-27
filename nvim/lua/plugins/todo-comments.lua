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
  },
}
