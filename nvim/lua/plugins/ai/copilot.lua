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

      LazyVim.cmp.actions.ai_show = function()
        if not suggestion.is_visible() then
          suggestion.next()
          return true
        end
      end

      LazyVim.cmp.actions.ai_hide = function()
        if suggestion.is_visible() then
          suggestion.dismiss()
          return true
        end
      end

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
      ---@module 'blink.cmp'
      local cmp = package.loaded["blink.cmp"]
      if cmp then
        local group = vim.api.nvim_create_augroup("blink-cmp-copilot", { clear = true })

        vim.api.nvim_create_autocmd("User", {
          pattern = "BlinkCmpListSelect",
          group = group,
          callback = function()
            if cmp.is_visible() and cmp.get_selected_item() ~= nil then
              suggestion.dismiss()
              vim.b.copilot_suggestion_auto_trigger = false
            end
          end,
        })

        vim.api.nvim_create_autocmd("User", {
          pattern = "BlinkCmpMenuClose",
          group = group,
          callback = function()
            vim.b.copilot_suggestion_auto_trigger = true
          end,
        })
      end
    end,
  },
}
