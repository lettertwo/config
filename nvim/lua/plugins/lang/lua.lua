return {
  { "HiPhish/neotest-busted", lazy = true },
  { "LuaCATS/luassert", name = "luassert-types", lazy = true },
  { "LuaCATS/busted", name = "busted-types", lazy = true },
  {
    "folke/lazydev.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.library, {
        { path = "luassert-types/library", words = { "assert" } },
        { path = "busted-types/library", words = { "describe" } },
      })
    end,
  },

  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        "neotest-busted",
      },
    },
  },

  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = {
      ensure_installed = {
        "local-lua-debugger-vscode",
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
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

  {
    "folke/which-key.nvim",
    ft = "lua",
    keys = {
      -- i?. expands to i ~= nil and i.<cursor>
      { "?.", " ~= <Esc>2Byt~f=a nil and <Esc>pr.a", mode = "i" },
      -- i += expands to i = i + <cursor>
      { "+=", "= <Esc>2Byt=f=lpa+ ", mode = "i" },
      -- i -= expands to i = i - <cursor>
      { "-=", "= <Esc>2Byt=f=lpa- ", mode = "i" },
      -- i ?= expands to i ~= nil and i = <cursor>
      { "?=", "~= <Esc>2Byt~f=a nil and <Esc>pa= ", mode = "i" },
    },
  },
}
