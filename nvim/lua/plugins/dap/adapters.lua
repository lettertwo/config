local M = {}

M.node2 = {
  opts = {
    type = "executable",
    command = "node",
    args = { vim.fn.stdpath("data") .. "/mason/packages/node-debug2-adapter/out/src/nodeDebug.js" },
  },
  setup = function(dap)
    dap.adapters.node2 = M.node2.opts
  end,
}

-- TODO: `js` is not the right name for an adapter type.
-- the nested `adapters` config here lists the actual adapter types.
-- It would be better if we could surface those types here, e.g.,
-- M['pwa-node'] = { ... }
M.js = {
  opts = {
    debugger_cmd = { "js-debug-adapter" },
    debugger_path = vim.fn.stdpath("data") .. "/mason/bin/js-debug-adapter",
    -- log_file_level = vim.log.levels.TRACE,
    adapters = {
      "pwa-node",
      "pwa-chrome",
      "pwa-msedge",
      "node-terminal",
      "pwa-extensionHost",
    },
  },
  setup = function(_)
    require("dap-vscode-js").setup(M.js.opts)
  end,
}

M.codelldb = {
  opts = {
    type = "server",
    port = "${port}",
    host = "12.0.0.1",
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
