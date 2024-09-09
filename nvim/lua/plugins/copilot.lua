return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      local copilot = require("copilot.suggestion")

      require("copilot").setup({
        panel = {
          enabled = false,
        },
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = "<down>",
            accept_word = "<right>",
            accept_line = false,
            next = "<up>",
            prev = false,
            dismiss = "<left>",
          },
        },
        filetypes = { markdown = true },
      })

      local function set_trigger(trigger)
        if not trigger and copilot.is_visible() then
          copilot.dismiss()
        end
        vim.b.copilot_suggestio_auto_trigger = trigger
        vim.b.copilot_suggestion_hidden = not trigger
      end

      -- Hide Copilot suggestions when using completion or inside snippets
      local cmp_ok, cmp = pcall(require, "cmp")

      if cmp_ok and cmp then
        cmp.event:on("menu_opened", function()
          set_trigger(false)
        end)

        cmp.event:on("menu_closed", function()
          set_trigger(not vim.snippet.active())
        end)
      end
    end,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    event = "VeryLazy",
    cmds = {
      "CopilotChat",
      "CopilotChatOpen",
      "CopilotChatClose",
      "CopilotChatToggle",
      "CopilotChatReset",
      "CopilotChatDebugInfo",
      "CopilotChatFix",
      "CopilotChatFixDiagnostic",
    },
    dependencies = {
      { "nvim-treesitter/nvim-treesitter" },
      { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    opts = {
      -- show_help = "yes", -- Show help text for CopilotChatInPlace, default: yes
      -- debug = true, -- Enable or disable debug mode, the log file will be in ~/.local/state/nvim/CopilotChat.nvim.log
      -- disable_extra_info = "no", -- Disable extra information (e.g: system prompt) in the response.
      -- language = "English", -- Copilot answer language settings when using default prompts. Default language is English.
      -- proxy = "socks5://127.0.0.1:3000", -- Proxies requests via https or socks.
      -- temperature = 0.1,
      -- window = {
      --   layout = "float",
      --   relative = "cursor",
      --   width = 1,
      --   height = 0.4,
      --   row = 1,
      -- },
      mappings = {
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        reset = {
          normal = "<C-l>",
          insert = "<C-l>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-CR>",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        yank_diff = {
          normal = "gy",
        },
        show_diff = {
          normal = "gd",
        },
        show_system_prompt = {
          normal = "gp",
        },
        show_user_selection = {
          normal = "gs",
        },
      },
    },
    keys = {
      { "<leader>cc", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat - Toggle" },
      { "<leader>cR", "<cmd>CopilotChatReset<cr>", desc = "CopilotChat - Reset" },
      { "<leader>cD", "<cmd>CopilotChatDebugInfo<cr>", desc = "CopilotChat - Debug info" },
      {
        "<leader>cq",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
      {
        "<leader>ch",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.help_actions())
        end,
        desc = "CopilotChat - Help actions",
      },
      -- Show prompts actions with telescope
      {
        "<leader>cp",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
        end,
        desc = "CopilotChat - Prompt actions",
      },
    },
  },
}
