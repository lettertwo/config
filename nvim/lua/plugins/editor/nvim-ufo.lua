return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    -- stylua: ignore
    keys = {
      { "zk", function() require('ufo').peekFoldedLinesUnderCursor() end, desc = "Peek folded lines" },
    },
    opts = {
      open_fold_hl_timeout = 0,
      fold_virt_text_handler = function(text, lnum, endLnum, width)
        local suffix = "  "
        local lines = ("(%d lines) "):format(endLnum - lnum)

        local cur_width = 0
        for _, section in ipairs(text) do
          cur_width = cur_width + vim.fn.strdisplaywidth(section[1])
        end

        suffix = suffix .. (" "):rep(width - cur_width - vim.fn.strdisplaywidth(lines) - 3)

        table.insert(text, { suffix, "Comment" })
        table.insert(text, { lines, "Todo" })
        return text
      end,
    },
    config = function(_, opts)
      require("ufo").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = require("lazyvim.config").filetypes.ui,
        callback = function()
          pcall(require("ufo").detach)
        end,
      })

      require("snacks").toggle
        .new({
          id = "ufo",
          name = "UFO",
          get = function()
            if vim.b.ufo ~= nil then
              return vim.b.ufo
            end
            return true
          end,
          set = function(state)
            vim.b.ufo = state
            if state then
              require("ufo").attach()
            else
              require("ufo").detach()
            end
          end,
        })
        :map("<leader>uu")
    end,
  },
}
