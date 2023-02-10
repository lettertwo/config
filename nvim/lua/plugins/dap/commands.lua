local M = {}

local function uninitialized_error()
  error("dap commands have not been initialized. Call require('plugins.dap.commands').setup first.")
end

M.start = uninitialized_error
M.restart = uninitialized_error
M.stop = uninitialized_error
M.clear_breakpoints = uninitialized_error

-- stylua: ignore
vim.api.nvim_create_user_command("DapStart", function() M.start() end, { desc = "Start a debugger session" })
-- stylua: ignore
vim.api.nvim_create_user_command("DapRestart", function() M.restart() end, { desc = "Restart a debugger session" })
-- stylua: ignore
vim.api.nvim_create_user_command("DapStop", function() M.stop() end, { desc = "Stop a debugger session" })
-- stylua: ignore
vim.api.nvim_create_user_command("DapClearBreakpoints", function() M.clear_breakpoints() end, { desc = "Clear all breakpoints" })

function M.setup(dap, ui)
  function M.start()
    dap.continue()
    ui.toggle({})
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-w>=", false, true, true), "n", false)
    vim.notify("Debugger session started", "warn")
  end

  function M.restart()
    dap.terminate()
    vim.defer_fn(function()
      dap.continue()
    end, 300)
  end

  function M.stop()
    dap.clear_breakpoints()
    ui.toggle({})
    dap.terminate()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-w>=", false, true, true), "n", false)
    vim.notify("Debugger session ended", "warn")
  end

  function M.clear_breakpoints()
    dap.clear_breakpoints()
    vim.notify("Breakpoints cleared", "warn")
  end
end

return M