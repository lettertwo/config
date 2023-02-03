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

return M
