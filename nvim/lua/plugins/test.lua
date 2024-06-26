local function run_all_tests()
  require("neotest").run.run(vim.fn.getcwd())
end

local function run_nearest_test()
  require("neotest").run.run()
end

local function run_current_file_tests()
  require("neotest").run.run(vim.fn.expand("%"))
end

local function debug_nearest_test()
  require("neotest").run.run({ strategy = "dap" })
end

local function stop_nearest_test()
  require("neotest").run.stop()
end

local function attach_to_nearest_test()
  require("neotest").run.attach()
end

local function toggle_watch_current_file()
  require("neotest").watch.toggle(vim.fn.expand("%"))
end

local function watch_nearest()
  require("neotest").watch.watch()
end

local function toggle_watch_nearest()
  require("neotest").watch.toggle()
end

local function open_nearest_test_output()
  require("neotest").output.open()
end

local function open_panel()
  require("neotest").output_panel.open()
end

local function open_summary()
  require("neotest").summary.open()
end

return {
  {
    "nvim-neotest/neotest",
    keys = {
      { "<leader>TT", open_summary, desc = "Open Test Summary" },
      { "<leader>Ta", run_all_tests, desc = "Run All Tests" },
      { "<leader>Tr", run_current_file_tests, desc = "Run Current File Tests" },
      { "<leader>Tw", toggle_watch_current_file, desc = "Toggle Watch Current File" },
      { "<leader>To", open_panel, desc = "Open Test Panel" },
      { "<leader>TR", run_nearest_test, desc = "Run Nearest Test" },
      { "<leader>TW", toggle_watch_nearest, desc = "Toggle Watch Nearest" },
      { "<leader>TD", debug_nearest_test, desc = "Debug Nearest Test" },
      { "<leader>TS", stop_nearest_test, desc = "Stop Nearest Test" },
      { "<leader>TA", attach_to_nearest_test, desc = "Attach to Nearest Test" },
      { "<leader>TK", open_nearest_test_output, desc = "Open Nearest Test Output" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-plenary",
      "adrigzr/neotest-mocha",
      "nvim-neotest/neotest-jest",
      "rouge8/neotest-rust",
    },
    config = function()
      require("neotest").setup({ ---@diagnostic disable-line: missing-fields
        adapters = {
          require("neotest-plenary"),
          require("neotest-rust")({
            args = { "--no-capture" },
            dap_adapter = "lldb",
          }),
          require("neotest-mocha")({
            command = "yarn test:integration",
            is_test_file = function(filename)
              return filename:match(".*/integration-tests/test/.*\\.js$")
            end,
            cwd = function()
              return vim.fn.getcwd()
            end,
          }),
          require("neotest-jest")({
            jestCommand = "yarn test",
            env = { CI = true },
            -- jestConfigFile = "custom.jest.config.ts",
            -- env = { CI = true },
            -- jestCommand = require("neotest-jest.jest-util").getJestCommand(vim.fn.expand("%:p:h")) .. " --watch",
            -- jestConfigFile = function()
            --   local file = vim.fn.expand("%:p")
            --   if string.find(file, "/packages/") then
            --     return string.match(file, "(.-/[^/]+/)src") .. "jest.config.ts"
            --   end
            --
            --   return vim.fn.getcwd() .. "/jest.config.ts"
            -- end,

            is_test_file = function(filename)
              vim.notify("checking filename: " .. filename, "info")
              return filename:match(".*/__tests__/.*\\.(?:j|t)sx?$")
            end,
            cwd = function(path)
              return vim.fn.getcwd()
            end,
          }),
        },
      })

      -- TODO: Get existing global config instead of redefining here.
      vim.diagnostic.config({
        update_in_insert = true,
        underline = true,
        severity_sort = true,
        virtual_text = true,
        virtual_lines = false,
        float = {
          focusable = false,
          close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
          style = "minimal",
          border = "rounded",
          source = "always",
          header = "",
          prefix = "",
        },
      }, vim.api.nvim_create_namespace("neotest"))
    end,
  },
}
