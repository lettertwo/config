local M = {}

M.attached_adapter = nil
M.attached_count = 0
M.attached_keys = nil

M.get_keys = function(dap, ui)
  return {
    { "<leader>d<cr>", "<cmd>DapStart<cr>", desc = "Start debugger session" },
    { "<leader>dd", "<cmd>DapToggle<cr>", desc = "Toggle debugger" },
    { "<leader>dL", "<cmd>DapShowLog<cr>", desc = "Show Log" },
    { "<Leader>db", dap.toggle_breakpoint, desc = "Toggle breakpoint" },
    -- { "<Leader>dB", dap.list_breakpoints, desc = "List breakpoints" },
    { "<leader>dC", "<cmd>DapClearBreakpoints<cr>", desc = "Clear Breakpoints" },
    {
      "<Leader>dc",
      function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end,
      desc = "Breakpoint condition",
    },
    {
      "<Leader>dm",
      function()
        dap.set_breakpoint({ nil, nil, vim.fn.input("Log point message: ") })
      end,
      desc = "Breakpoint message",
    },
  }
end

M.get_attached_keys = function(dap, ui)
  return {
    { "<leader>d<cr>", "<cmd>DapContinue<cr>", desc = "Continue" },
    { "<leader>dl", "<cmd>DapStepOver<cr>", desc = "Step Over" },
    { "<leader>dj", "<cmd>DapStepInto<cr>", desc = "Step Into" },
    { "<leader>dk", "<cmd>DapStepOut<cr>", desc = "Step Out" },
    { "<leader>dr", "<cmd>DapRestartFrame<cr>", desc = "Restart Frame" },
    { "<leader>dR", "<cmd>DapRestart<cr>", desc = "Restart" },
    { "<leader>dq", "<cmd>DapStop<cr>", desc = "Stop debugging" },
    { "<leader>dt", "<cmd>DapToggleRepl<cr>", desc = "Toggle Repl" },

    -- { "<leader>dv", dap.ui.variables.hover, desc = "List variables" },
    -- { "<leader>df", dap.ui.variables.scopes, desc = "List Frames" },

    -- TODO: Incorporate these into hover (K)
    -- { "<Leader>dhh", dap.ui.variables.hover, desc = "Hover" },
    -- { "<Leader>dhv", dap.ui.variables.visual_hover, mode = "v", desc = "Hover" },
    -- { "<Leader>duh", dap.ui.widgets.hover, desc = "UI Hover" },

    -- stylua: ignore
    -- { "<leader>duf", function() ui.widgets.centered_float(ui.widgets.scopes) end, desc = "List scopes" },

    -- { "n", "<Leader>dro", ":lua require('dap').repl.open()<CR>" },
    -- { "n", "<Leader>drl", ":lua require('dap').repl.run_last()<CR>" },
  }
end

function M.activate_keys(config)
  local Keys = require("lazy.core.handler.keys")

  local keymaps = {}
  for _, value in ipairs(config) do
    local keys = Keys.parse(value)
    keymaps[keys.id] = keys
  end

  for _, keys in pairs(keymaps) do
    local opts = Keys.opts(keys)
    opts.silent = true
    vim.keymap.set(keys.mode or "n", keys[1], keys[2], opts)
  end

  return keymaps
end

function M.deactivate_keys(config)
  local Keys = require("lazy.core.handler.keys")

  for _, keys in pairs(config) do
    local opts = Keys.opts(keys)
    opts.silent = true
    vim.keymap.del(keys.mode or "n", keys[1], opts)
  end
end

function M.on_attach(client)
  if M.attached_count > 0 and M.attached_adapter ~= client.adapter.id then
    error("Already attached to " .. M.attached_adapter)
  end

  M.attached_count = M.attached_count + 1

  if M.attached_count == 1 then
    M.attached_adapter = client.adapter.id
    M.activate_keys(M.attached_keys)
  end
end

function M.on_detach(client)
  if M.attached_adapter ~= client.adapter.id then
    error("Not attached to " .. client.adapter.id)
  end

  M.attached_count = M.attached_count - 1

  if M.attached_count == 0 then
    M.attached_adapter = nil
    M.deactivate_keys(M.attached_keys)
  end
end

function M.setup(dap, ui)
  M.activate_keys(M.get_keys(dap, ui))
  M.attached_keys = M.get_attached_keys(dap, ui)

  dap.listeners.after.event_initialized.dap_keymaps = M.on_attach
  dap.listeners.before.event_terminated.dap_keymaps = M.on_detach
  dap.listeners.before.event_exited.dap_keymaps = M.on_detach
end

return M
