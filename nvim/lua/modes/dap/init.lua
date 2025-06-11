local Util = require("util")

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "jbyuki/one-small-step-for-vimkind",
      "mxsdev/nvim-dap-vscode-js",
      -- "nvim-telescope/telescope-dap.nvim",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "debugloop/layers.nvim",
    },
    cmd = {
      "DapStart",
    },
    keys = {
      { "<leader>d", "<cmd>DapStart<cr>", desc = "Start debugger session" },
      -- { "<leader>dd", "<cmd>DapToggle<cr>", desc = "Toggle debugger" },
      -- { "<leader>dL", "<cmd>DapShowLog<cr>", desc = "Show Log" },
      -- { "<Leader>db", "<cmd>DapToggleBreakpoint<cr>", desc = "Toggle breakpoint" },
      -- { "<Leader>dc", "<cmd>DapToggleBreakpointCondition<cr>", desc = "Toggle breakpoint condition" },
      -- { "<Leader>dm", "<cmd>DapToggleBreakpointMessage<cr>", desc = "Toggle breakpoint message" },
      -- { "<Leader>dB", "<cmd>DapListBreakpoints<cr>", desc = "List breakpoints" },
      -- { "<leader>dC", "<cmd>DapClearBreakpoints<cr>", desc = "Clear Breakpoints" },
    },
    config = function()
      local dap = require("dap")
      local ui = require("dapui")
      local icons = require("config").icons
      local Layers = require("layers")

      local mode = Layers.mode.new()
      mode:auto_show_help()
      mode:add_hook(function(_)
        vim.cmd("redrawstatus") -- update status line when toggled
      end)

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

      require("modes.dap.commands").setup(mode, dap, ui)
      require("modes.dap.keymaps").setup(mode, dap, ui)
      require("modes.dap.ui").setup(dap, ui)
      require("nvim-dap-virtual-text").setup({})
    end,
  },
}
