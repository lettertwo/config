return {
  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    dependencies = {
      "jay-babu/mason-nvim-dap.nvim",
      "jbyuki/one-small-step-for-vimkind",
      "mxsdev/nvim-dap-vscode-js",
      -- "nvim-telescope/telescope-dap.nvim",
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap = require("dap")
      local ui = require("dapui")

      -- dap.set_log_level("TRACE")

      -- local telescope = require("telescope")
      -- telescope.load_extension("dap")

      local adapters = require("plugins.dap.adapters")

      require("mason-nvim-dap").setup({
        ensure_installed = vim.tbl_keys(adapters),
      })

      for _, adapter in pairs(adapters) do
        adapter.setup(dap)
      end

      dap.configurations = require("plugins.dap.configurations")

      -- Try to load launch.json
      if not pcall(require("dap.ext.vscode").load_launchjs, nil, {}) then
        vim.notify("Failed to parse launch.json", "warn")
      end

      require("plugins.dap.commands").setup(dap, ui)
      require("plugins.dap.keymaps").setup(dap, ui)
      require("plugins.dap.ui").setup(dap, ui)
      require("nvim-dap-virtual-text").setup({})
      vim.notify("DAP INITIALIZED")
    end,
  },
}
