return {
  -- TODO: Look into a mini-files like version of nvim-navbuddy
  -- also see: https://marketplace.visualstudio.com/items?itemName=mxsdev.typescript-explorer
  {
    "Bekaboo/dropbar.nvim",
    event = "VeryLazy",
    opts = function()
      local icons = LazyVim.config.icons

      return {
        icons = {
          ui = {
            bar = {
              separator = icons.separator,
            },
          },
          kinds = {
            symbols = icons,
          },
        },
        bar = {
          enable = false,
          padding = { left = 0, right = 0 },
          truncate = false,
          sources = function(buf, _)
            local sources = require("dropbar.sources")
            local utils = require("dropbar.utils")

            if vim.bo[buf].ft == "markdown" then
              return {
                -- path,
                utils.source.fallback({
                  sources.treesitter,
                  sources.markdown,
                  sources.lsp,
                }),
              }
            end
            return {
              -- path,
              utils.source.fallback({
                sources.lsp,
                sources.treesitter,
              }),
            }
          end,
        },
        -- menu = {
        --   win_configs = {
        --     border = "single",
        --   },
        -- },
        sources = {
          path = {
            relative_to = function(bufno)
              -- get dirname of current buffer
              return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufno), ":p:h")
            end,
          },
        },
      }
    end,
  },
}
