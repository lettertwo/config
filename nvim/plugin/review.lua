-- Embedded :Review command — opens a review session in a new tab via the app
-- framework's embedded launch (handles tabnew + teardown + tab restoration).
-- Works from any app context (default or otherwise).

vim.api.nvim_create_user_command("Review", function(cmd_opts)
  _G.App.launch("review", {
    context = "embedded",
    args = { source = vim.trim(cmd_opts.args) },
  })
end, {
  nargs = "?",
  desc = "Open a review session in a new tab",
  complete = function()
    return { "stack", "uncommitted" }
  end,
})
