local map = vim.keymap.set

vim.schedule(function()
  Config.add("kevinhwang91/nvim-bqf")
  Config.add("stevearc/quicker.nvim")

  require("bqf").setup(
    ---@module "bqf"
    ---@type BqfConfig
    {
      auto_resize_height = true,
    }
  )

  local quicker = require("quicker")

  quicker.setup(
    ---@module "quicker"
    ---@type quicker.SetupOptions
    {
      -- Keymaps to set for the quickfix buffer
      -- stylua: ignore
      keys = {
        { ">", function() quicker.expand({ before = 2, after = 2, add_to_existing = true }) end, desc = "Expand quickfix content" },
        { "<", function() quicker.collapse() end, desc = "Collapse quickfix content" },
      },
      on_qf = function(bufnr)
        map("n", "<leader>xr", function()
          local win = vim.api.nvim_get_current_win()
          if quicker.is_open(win) then
            quicker.refresh(win)
          else
            quicker.refresh()
          end
        end, { buffer = bufnr, desc = "Refresh Quickfix/Loclist" })
      end,
      highlight = {
        treesitter = true,
        lsp = true,
        -- Load the referenced buffers to apply more accurate highlights (may be slow)
        load_buffers = true,
      },
      type_icons = {
        E = Config.icons.diagnostics.Error,
        W = Config.icons.diagnostics.Warn,
        I = Config.icons.diagnostics.Info,
        N = Config.icons.diagnostics.Info,
        H = Config.icons.diagnostics.Hint,
      },
      -- Border characters
      borders = {
        vert = " ",
        -- Strong headers separate results from different files
        strong_header = "━",
        strong_cross = "━",
        strong_end = "━",
        -- Soft headers separate results within the same file
        soft_header = "╌",
        soft_cross = "╌",
        soft_end = "╌",
      },
    }
  )

  map("n", "<leader>xq", function()
    require("quicker").toggle({ focus = true })
  end, { desc = "Quickfix List" })

  map("n", "<leader>xl", function()
    require("quicker").toggle({ focus = true, loclist = true })
  end, { desc = "Location List" })
end)
