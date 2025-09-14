return {
  {
    "debugloop/layers.nvim",
    dependencies = {
      {
        "mfussenegger/nvim-dap",
        -- stylua: ignore
        keys = {
          { "<leader>dm", function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: ")) end, desc = "Log Point" },
          { "<leader>dM", function() require("dap").set_breakpoint(vim.fn.input("Log point condition: "), nil, vim.fn.input('Log point message: ')) end, desc = "Log Point Condition" },
          { "<leader>xd", function() require("dap").list_breakpoints(true) end, desc = "Breakpoints" },
          { "<leader>d<cr>", "<leader>dc", remap = true, desc = "Run/Continue" },
          { "<leader>dx", "<leader>xd", remap = true, desc = "Breakpoints" },
          { "<leader>d<tab>", "<leader>db", remap = true, desc = "Breakpoint" },
          { "<leader>d<S-tab>", "<leader>dB", remap = true, desc = "Breakpoint Condition" },

          -- Disable a bunch of LazyVim default dap kemyaps; we'll manage these via DEBUG_MODE
          { "<leader>dC", false },
          { "<leader>dg", false },
          { "<leader>di", false },
          { "<leader>dj", false },
          { "<leader>dk", false },
          { "<leader>do", false },
          { "<leader>dO", false },
          { "<leader>dP", false },
          { "<leader>dr", false },
          { "<leader>ds", false },
          { "<leader>dw", false },
        },
      },
      { "rcarriga/nvim-dap-ui", enabled = false },
      {
        "igorlfs/nvim-dap-view",
        ---@module 'dap-view'
        ---@type dapview.Config
        opts = {
          winbar = {
            show = true,
            sections = {
              "scopes",
              "watches",
              "threads",
              "repl",
              "breakpoints",
              "exceptions",
            },
            default_section = "scopes",
          },
          windows = {
            terminal = {
              start_hidden = true,
              hide = {},
            },
          },
        },
        config = function(_, opts)
          local dap = require("dap")

          -- Hide dap-view terminal for all adapters
          for adapter, _ in pairs(dap.adapters) do
            table.insert(opts.windows.terminal.hide, adapter)
          end

          local dap_view = require("dap-view")
          dap_view.setup(opts)

          dap.listeners.after.event_initialized["dap_view"] = function()
            dap_view.open()
          end
          dap.listeners.before.event_exited["dap_view"] = function()
            dap_view.close(true)
          end
          dap.listeners.before.event_terminated["dap_view"] = function()
            dap_view.close(true)
          end
          dap.listeners.before.terminate["dap_view"] = function()
            dap_view.close(true)
          end

          vim.keymap.set("n", "<leader>du", function()
            dap_view.toggle()
          end, { desc = "DAP View" })
        end,
      },
    },
    config = function()
      local dap = require("dap")
      local dap_view = require("dap-view")
      local Layers = require("layers")

      DEBUG_MODE = Layers.mode.new("DEBUG MODE")
      DEBUG_MODE:auto_show_help()
      DEBUG_MODE:add_hook(function()
        vim.cmd("redrawstatus") -- update status line when toggled
      end)
      -- nvim-dap hooks
      dap.listeners.after.event_initialized["debug_mode"] = function()
        if not DEBUG_MODE:active() then
          DEBUG_MODE:activate()
        end
      end
      dap.listeners.before.event_terminated["debug_mode"] = function()
        if DEBUG_MODE:active() then
          DEBUG_MODE:deactivate()
        end
      end
      dap.listeners.before.event_exited["debug_mode"] = function()
        if DEBUG_MODE:active() then
          DEBUG_MODE:deactivate()
        end
      end
      dap.listeners.before.terminate["debug_mode"] = function()
        if DEBUG_MODE:active() then
          DEBUG_MODE:deactivate()
        end
      end

      local function toggle_debug_mode()
        if DEBUG_MODE:active() then
          dap_view.close(true)
          DEBUG_MODE:deactivate()
        else
          dap_view.open()
          DEBUG_MODE:activate()
        end
      end

      -- map our custom mode keymaps
      DEBUG_MODE:keymaps({
        -- stylua: ignore
        n = {
          { "<cr>", function() dap.continue() end, { desc = "Run/Continue" } },
          { "<tab>", function() dap.toggle_breakpoint(nil, tostring(vim.v.count1)) end, { desc = "Breakpoint" } },
          { "S<tab>", function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, { desc = "Breakpoint Condition" } },
          { "m", function() dap.set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end, { desc = "Log Point" } },
          { "M", function() dap.set_breakpoint(vim.fn.input("Log point condition: "), nil, vim.fn.input('Log point message: ')) end, { desc = "Log Point Condition" } },
          { "x", function() dap.list_breakpoints(true) end, { desc = "List Breakpoints" } },
          { "c", function() dap.continue() end, { desc = "Run/Continue" } },
          { "C", function() dap.run_to_cursor() end, { desc = "Run to Cursor" } },
          { "i", function() dap.step_into() end, { desc = "Step Into" } },
          { "o", function() dap.step_over() end, { desc = "Step Over" } },
          { "O", function() dap.step_out() end, { desc = "Step Out" } },
          { "u", function() dap_view.toggle() end, { desc = "DAP View" } },
          { "dd", toggle_debug_mode, { desc = "Debug Mode" } },
          { "e", function() dap_view.add_expr() end, { desc = "Add Expression" } },
          { "E", function() dap_view.open(); dap_view.jump_to_view("exceptions") end, { desc = "Add Expression" } },
          { "R", function() dap_view.open(); dap_view.jump_to_view("repl") end, { desc = "REPL" } },
          { "S", function() dap_view.open(); dap_view.jump_to_view("scopes") end, { desc = "Scopes" } },
          { "T", function() dap_view.open(); dap_view.jump_to_view("threads") end, { desc = "Threads" } },
          { "W", function() dap_view.open(); dap_view.jump_to_view("watches") end, { desc = "Watches" } },
          { "t", function() dap.terminate() end, { desc = "Terminate" } },
          { "K", function() require("dap.ui.widgets").hover() end, { desc = "Widgets" } },

          -- TODO: Incorporate these into hover (K)
          -- { "<Leader>dhh", dap.ui.variables.hover, desc = "Hover" },
          -- { "<Leader>dhv", dap.ui.variables.visual_hover, mode = "v", desc = "Hover" },
          -- { "<leader>dhf", dap.ui.variables.scopes, desc = "List Frames" },
          -- { "<Leader>duh", dap.ui.widgets.hover, desc = "UI Hover" },
        },
      })

      vim.keymap.set("n", "<leader>dd", toggle_debug_mode, { desc = "Debug Mode" })
    end,
  },
}
