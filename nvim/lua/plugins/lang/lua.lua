return {
  {
    "folke/lazydev.nvim",
    dependencies = {
      { "LuaCATS/luassert", name = "luassert-types" },
      { "LuaCATS/busted", name = "busted-types" },
    },
    opts = function(_, opts)
      vim.list_extend(opts.library, {
        { path = "luassert-types/library", words = { "assert" } },
        { path = "busted-types/library", words = { "describe" } },
      })
    end,
  },

  {
    "nvim-neotest/neotest",
    dependencies = {
      "HiPhish/neotest-busted",
    },
    optional = true,
    opts = function(_, opts)
      vim.list_extend(opts.adapters, { "neotest-busted" })
    end,
  },

  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = {
      ensure_installed = {
        "local-lua-debugger-vscode",
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function(_, opts)
      local dap = require("dap")

      dap.adapters["local-lua"] = {
        type = "executable",
        command = "node",
        args = {
          vim.fn.expand("$MASON/share/local-lua-debugger-vscode/extension/debugAdapter.js"),
        },
      }

      dap.configurations.lua = {
        {
          name = "Current file (local-lua-dbg, lua)",
          type = "local-lua",
          repl_lang = "lua",
          request = "launch",
          cwd = "${workspaceFolder}",
          program = {
            lua = "luajit",
            file = "${file}",
          },
          verbose = true,
          extensionPath = vim.fn.expand("$MASON/share/local-lua-debugger-vscode/"),
          args = {},
        },
        {
          name = "Current file (local-lua-dbg, neovim lua interpreter with nlua)",
          type = "local-lua",
          repl_lang = "lua",
          request = "launch",
          cwd = "${workspaceFolder}",
          program = {
            lua = "nlua",
            file = "${file}",
          },
          verbose = true,
          extensionPath = vim.fn.expand("$MASON/share/local-lua-debugger-vscode/"),
          args = {},
        },
      }
    end,
  },
}
