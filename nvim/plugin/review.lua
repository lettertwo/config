-- Embedded :Review command — opens a review session in a new tab via the app
-- framework's embedded launch (handles tabnew + teardown + tab restoration).
-- Works from any app context (default or otherwise).

vim.api.nvim_create_user_command("Review", function(cmd_opts)
  local parts = vim.split(vim.trim(cmd_opts.args), "%s+", { trimempty = true })
  local kind = parts[1] or "uncommitted"
  _G.App.launch("review", {
    context = "embedded",
    args = { kind = kind },
  })
end, {
  nargs = "?",
  desc = "Open a review session in a new tab",
  complete = function()
    return { "uncommitted", "stack", "pr", "ref" }
  end,
})
