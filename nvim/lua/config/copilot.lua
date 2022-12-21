local status_ok, copilot = pcall(require, "copilot")
if not status_ok then
  return
end

copilot.setup({
  copilot_node_command = vim.fn.expand("$FNM_MULTISHELL_PATH") .. "/bin/node",
})
