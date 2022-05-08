local Dap = {}

function Dap.config()
  if not lvim.builtin.dap.active then
    return
  end

  local dap = require("dap")
  dap.adapters.jsnode = {
    type = "executable",
    command = "node",
    args = { os.getenv("HOME") .. "/.local/share/nvim/dapinstall/jsnode/vscode-node-debug2/out/src/nodeDebug.js" },
  }

  dap.configurations.javascript = {
    {
      name = "Attach to process",
      type = "jsnode",
      request = "attach",
      pid = require("dap.utils").pick_process,
      protocol = "inspector",
    },
  }
end

return Dap
