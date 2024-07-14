local M = {}

M.node2 = {
  opts = {
    type = "executable",
    command = "node",
    args = { vim.fn.stdpath("data") .. "/mason/packages/node-debug2-adapter/out/src/nodeDebug.js" },
  },
  setup = function(dap)
    dap.adapters.node2 = M.node2.opts
    dap.adapters.node = M.node2.opts
  end,
}

M.js = {
  opts = {
    type = "server",
    port = "${port}",
    host = "127.0.0.1",
    executable = {
      command = "node",
      args = {
        require("mason-registry").get_package("js-debug-adapter"):get_install_path()
          .. "/js-debug/src/dapDebugServer.js",
        "${port}",
      },
    },
    -- debugger_cmd = { "js-debug-adapter" },
    -- debugger_path = require("mason-registry").get_package("js-debug-adapter"):get_install_path(),
    -- -- -- log_file_level = vim.log.levels.TRACE,

    --   Error  12:41:05 notify.error [dap-js] Error trying to launch JS debugger: ...nvim/lazy/nvim-dap-vscode-js/lua/dap-vscode-js/utils.lua:64:
    -- Debugger entrypoint file '/Users/eeldredge/.local/share/nvim/site/pack/packer/opt/vscode-js-debug/out/src/vsDebugServer.js' does not exist. Did it build properly?
    -- adapters = {
    --   "pwa-node",
    --   "pwa-chrome",
    --   "pwa-msedge",
    --   "node-terminal",
    --   "pwa-extensionHost",
    -- },
  },
  setup = function(dap)
    for _, adapter in ipairs({ "pwa-node", "pwa-chrome", "pwa-msedge", "pwa-extensionHost", "node-terminal", "node" }) do
      dap.adapters[adapter] = M.js.opts
    end
    -- dap.adapters.node = M.js.opts
  end,
}

M.codelldb = {
  opts = {
    type = "server",
    port = "${port}",
    host = "127.0.0.1",
    executable = {
      command = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb",
      args = {
        "--liblldb",
        vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/lldb/lib/liblldb.dylib",
        "--port",
        "${port}",
      },
    },
  },
  setup = function(dap)
    dap.adapters.codelldb = M.codelldb.opts
  end,
}

return M
