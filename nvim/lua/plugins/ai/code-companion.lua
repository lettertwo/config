---@module 'codecompanion'

return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/mcphub.nvim",
    },
    init = function()
      vim.g.codecompanion_auto_tool_mode = true

      --- Limit undo levels for CodeCompanion buffer. This *might* improve performance.
      --- See https://github.com/olimorris/codecompanion.nvim/issues/552#issuecomment-2984548382
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("LimitCCUndoBuffer", { clear = true }),
        pattern = { "codecompanion" },
        callback = function()
          vim.bo.undolevels = 3
        end,
      })
    end,
    opts = {
      extensions = {
        mcphub = {
          callback = "mcphub.extensions.codecompanion",
          opts = {
            make_vars = true,
            make_slash_commands = true,
            show_result_in_chat = true,
          },
        },
      },
      strategies = {
        chat = {
          opts = {
            goto_file_action = "edit", -- Action to perform when clicking on a file link in the chat
          },
          keymaps = {
            close = {
              modes = {
                n = "<C-q>",
                i = "<C-q>",
              },
            },
            stop = {
              modes = {
                n = "<C-c>",
                i = "<C-c>",
              },
            },
          },
          roles = {
            ---The header name for the LLM's messages
            ---@type string|fun(adapter: CodeCompanion.Adapter): string
            llm = function(adapter)
              return adapter.formatted_name .. " (" .. adapter.model.name .. ")"
            end,
            user = os.getenv("USER") or "me",
          },
          tools = {
            opts = {
              auto_submit_errors = true, -- Send any errors to the LLM automatically?
              auto_submit_success = true, -- Send any successful output to the LLM automatically?
            },
          },
        },
      },
    },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionCmd", "CodeCompanionActions" },
    keys = {
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      { "<leader>aa", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle (CodeCompanion)", mode = { "n", "v" } },
      { "<leader>ac", "<cmd>CodeCompanionCmd<cr>", desc = "Generate command (CodeCompanion)", mode = { "n", "v" } },
      { "<leader>ai", "<cmd>CodeCompanion<cr>", desc = "Inline Assistant (CodeCompanion)", mode = { "n", "v" } },
      { "<leader>ap", "<cmd>CodeCompanionActions<cr>", desc = "Prompt Actions (CodeCompanion)", mode = { "n", "v" } },
      { "<C-a>", "<cmd>CodeCompanionActions<cr>", desc = "Prompt Actions (CodeCompanion", mode = { "n", "v" } },
      { "ga", "<cmd>CodeCompanionChat Add<cr>", desc = "Add to chat (CodeCompanion)", mode = "v" },
      { "q", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle (CodeCompanion)", ft = "codecompanion" },
      { "<Esc>", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle (CodeCompanion)", ft = "codecompanion" },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    ft = { "codecompanion" },
  },
}
