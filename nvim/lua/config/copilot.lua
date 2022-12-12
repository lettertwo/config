local status_ok, copilot = pcall(require, "copilot")
if not status_ok then
  return
end

copilot.setup({
  -- copilot_node_command = "fnm exec --using=v16 node",
  copilot_node_command = vim.fn.expand("$FNM_MULTISHELL_PATH") .. "/bin/node",
  cmp = {
    enabled = true,
    method = "getCompletionsCycling",
  },
  panel = {
    enabled = true,
  },
})

-- local function test()
-- end

