return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        auto_trigger = true,
        -- copilot actions triggered through cmp keymaps.
        keymap = {
          accept = false,
          accept_word = false,
          accept_line = false,
          next = false,
          prev = false,
          dismiss = "<left>",
        },
      },
    },
    config = function(_, opts)
      local copilot = require("copilot")
      copilot.setup(opts)

      local suggestion = require("copilot.suggestion")

      local LazyVim = require("lazyvim.util")

      LazyVim.cmp.actions.ai_select_prev = function()
        if suggestion.is_visible() then
          suggestion.prev()
          return true
        end
      end

      LazyVim.cmp.actions.ai_select_next = function()
        if suggestion.is_visible() then
          suggestion.next()
          return true
        end
      end

      LazyVim.cmp.actions.ai_accept_line = function()
        if suggestion.is_visible() then
          suggestion.accept_line()
          return true
        end
      end

      LazyVim.cmp.actions.ai_accept_word = function()
        if suggestion.is_visible() then
          suggestion.accept_word()
          return true
        end
      end

      -- Hide Copilot suggestions when using completion
      ---@module 'cmp'
      local cmp = package.loaded["cmp"]
      if cmp then
        cmp.event:on("menu_opened", function()
          suggestion.dismiss()
          vim.b.copilot_suggestion_auto_trigger = false
        end)

        cmp.event:on("menu_closed", function()
          vim.b.copilot_suggestion_auto_trigger = true
        end)
      end
    end,
  },
}
