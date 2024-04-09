local Util = require("util")

return {
  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    dependencies = {
      "jbyuki/one-small-step-for-vimkind",
      "mxsdev/nvim-dap-vscode-js",
      -- "nvim-telescope/telescope-dap.nvim",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap = require("dap")
      local ui = require("dapui")
      local icons = require("config").icons

      vim.fn.sign_define("DapBreakpoint", { text = icons.dap.Breakpoint, texthl = "DiagnosticInfo" })
      vim.fn.sign_define("DapBreakpointCondition", { text = icons.dap.BreakpointCondition })
      vim.fn.sign_define("DapBreakpointRejected", { text = icons.dap.BreakpointRejected, texthl = "DiagnosticError" })
      vim.fn.sign_define("DapLogPoint", { text = icons.dap.LogPoint })
      vim.fn.sign_define("DapStopped", { text = icons.dap.Stopped, texthl = "DiagnosticWarn" })

      -- dap.set_log_level("TRACE")

      -- local telescope = require("telescope")
      -- telescope.load_extension("dap")

      local adapters = require("modes.dap.adapters")

      Util.ensure_installed(vim.tbl_keys(adapters))

      for _, adapter in pairs(adapters) do
        adapter.setup(dap)
      end

      dap.configurations = require("modes.dap.configurations")

      -- Try to load launch.json
      if not pcall(require("dap.ext.vscode").load_launchjs, nil, {}) then
        vim.notify("Failed to parse launch.json", "warn")
      end

      require("modes.dap.commands").setup(dap, ui)
      require("modes.dap.keymaps").setup(dap, ui)
      require("modes.dap.ui").setup(dap, ui)
      require("nvim-dap-virtual-text").setup({})
    end,
  },
}
