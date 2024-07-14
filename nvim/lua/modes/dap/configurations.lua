local M = {}

-- TODO: Add https://zignar.net/2023/06/10/debugging-lua-in-neovim/
-- M.lua = {
--   name = "Current file (local-lua-db, lua)",
--   type = "local-lua",
--   request = "launch",
--   cwd = "${workspaceFolder}",
--   program = {
--     lua = "lua5.1",
--     file = "${file}",
--   },
--   args = {},
-- }

M.javascript = {
  -- {
  --   type = "node",
  --   name = "Launch",
  --   request = "launch",
  --   program = "${file}",
  --   cwd = vim.fn.getcwd(),
  --   sourceMaps = true,
  --   protocol = "inspector",
  --   console = "integratedTerminal",
  -- },
  -- {
  --   type = "node",
  --   name = "Attach (node)",
  --   request = "attach",
  --   program = "${file}",
  --   cwd = vim.fn.getcwd(),
  --   sourceMaps = true,
  --   protocol = "inspector",
  --   console = "integratedTerminal",
  -- },
  -- {
  --   type = "pwa-node",
  --   name = "Launch Parcel (js-debug)",
  --   request = "launch",
  --   runtimeArgs = { "--inspect", "${workspaceFolder}/node_modules/.bin/parcel" },
  --   runtimeExecutable = "node",
  --   cwd = "${workspaceFolder}",
  --   console = "integratedTerminal",
  --   -- internalConsoleOptions = "neverOpen",
  --   -- protocol = "inspector",
  --   sourceMaps = true,
  --   skipFiles = { "<node_internals>/**" },
  --   -- resolveSourceMapLocations = {
  --   --   "${workspaceFolder}/**",
  --   --   "!**/node_modules/**",
  --   -- },
  -- },
  {
    type = "pwa-node",
    name = "Attach (js-debug)",
    request = "attach",
    processId = require("dap.utils").pick_process,
    cwd = "${workspaceFolder}",
    skipFiles = { "<node_internals>/**" },
    sourceMaps = true,
    resolveSourceMapLocations = {
      "${workspaceFolder}/**",
      "!**/node_modules/**",
    },
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
  {
    name = "lldb debug",
    type = "codelldb",
    request = "launch",
    program = "/Users/eeldredge/.local/state/fnm_multishells/72638_1698867372675/bin/node",
    args = {
      "${workspaceFolder}/node_modules/.bin/parcel",
      "start",
    },
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    runInTerminal = false,
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
