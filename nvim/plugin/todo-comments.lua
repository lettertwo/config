local map = vim.keymap.set

vim.schedule(function()
  Config.add("folke/todo-comments.nvim")
  require("todo-comments").setup({
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
  })

  map("n", "<leader>st", function()
    ---@diagnostic disable-next-line: undefined-field
    Snacks.picker.todo_comments()
  end, { desc = "Todo" })
  map("n", "<leader>sT", function()
    ---@diagnostic disable-next-line: undefined-field
    Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } })
  end, { desc = "Todo/Fix/Fixme" })
end)
