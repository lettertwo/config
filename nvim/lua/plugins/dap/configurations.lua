local M = {}

M.javascript = {
  {
    type = "node2",
    name = "Launch",
    request = "launch",
    program = "${file}",
    cwd = vim.fn.getcwd(),
    sourceMaps = true,
    protocol = "inspector",
    console = "integratedTerminal",
  },
  {
    type = "node2",
    name = "Attach",
    request = "attach",
    program = "${file}",
    cwd = vim.fn.getcwd(),
    sourceMaps = true,
    protocol = "inspector",
    console = "integratedTerminal",
  },
}

M.javascriptreact = {
  {
    type = "pwa-node",
    name = "Launch",
    request = "launch",
    program = "${file}",
    cwd = "${workspaceFolder}",
    resolveSourceMapLocations = {
      "${workspaceFolder}/**",
      "!**/node_modules/**",
    },
  },
  {
    type = "pwa-node",
    name = "Attach",
    request = "attach",
    processId = require("dap.utils").pick_process,
    cwd = "${workspaceFolder}",
    resolveSourceMapLocations = {
      "${workspaceFolder}/**",
      "!**/node_modules/**",
    },
  },
}

M.typescript = M.javascript
M.typescriptreact = M.javascriptreact

M.flowtype = M.javascript
M.flowtypereact = M.javascriptreact

M.rust = {
  {
    name = "rust debug",
    type = "codelldb",
    request = "launch",
    program = "${workspaceFolder}/target/debug/app",
    -- program = function()
    --   return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
    -- end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    args = {},

    -- if you change `runInTerminal` to true, you might need to change the yama/ptrace_scope setting:
    --
    --    echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
    --
    -- Otherwise you might get the following error:
    --
    --    Error on launch: Failed to attach to the target process
    --
    -- But you should be aware of the implications:
    -- https://www.kernel.org/doc/html/latest/admin-guide/LSM/Yama.html
    runInTerminal = false,
  },
}

return M
