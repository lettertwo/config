return {
  { "MagicDuck/grug-far.nvim", enabled = false },
  {
    "stevearc/quicker.nvim",
    dependencies = {
      { "kevinhwang91/nvim-bqf", ft = "qf", opts = {} },
    },
    event = "FileType qf",
    cmd = { "ToggleQuickfix", "ToggleLoclist", "RefreshQuickfix" },
    keys = {
      { "<leader>xq", "<cmd>ToggleQuickfix<cr>", desc = "Toggle QuickFix" },
      { "<leader>xl", "<cmd>ToggleLoclist<cr>", desc = "Toggle Locationlist" },
      { "<leader>xr", "<cmd>RefreshQuickfix<cr>", desc = "Refresh Quickfix/Loclist" },
    },
    ---@module "quicker"
    ---@type quicker.SetupOptions
    opts = {
      -- Local options to set for quickfix
      opts = {
        buflisted = false,
        number = false,
        relativenumber = false,
        signcolumn = "auto",
        winfixheight = true,
        wrap = false,
      },
      -- Set to false to disable the default options in `opts`
      use_default_opts = true,
      -- Keymaps to set for the quickfix buffer
      keys = {
        {
          ">",
          function()
            require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
          end,
          desc = "Expand quickfix content",
        },
        {
          "<",
          function()
            require("quicker").collapse()
          end,
          desc = "Collapse quickfix content",
        },
      },
      -- Callback function to run any custom logic or keymaps for the quickfix buffer
      -- on_qf = function(bufnr) end,
      edit = {
        -- Enable editing the quickfix like a normal buffer
        enabled = true,
        -- Set to true to write buffers after applying edits.
        -- Set to "unmodified" to only write unmodified buffers.
        autosave = "unmodified",
      },
      -- Keep the cursor to the right of the filename and lnum columns
      constrain_cursor = true,
      highlight = {
        -- Use treesitter highlighting
        treesitter = true,
        -- Use LSP semantic token highlighting
        lsp = true,
        -- Load the referenced buffers to apply more accurate highlights (may be slow)
        load_buffers = true,
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
      -- Trim the leading whitespace from results
      trim_leading_whitespace = true,
      -- Maximum width of the filename column
      -- max_filename_width = function()
      --   return math.floor(math.min(95, vim.o.columns / 2))
      -- end,
      -- How far the header should extend to the right
      -- header_length = function(type, start_col)
      --   return vim.o.columns - start_col
      -- end,
    },
    config = function(_, opts)
      local quicker = require("quicker")
      local icons = require("lazyvim.config").icons

      -- Map of quickfix item type to icon
      opts.type_icons = {
        E = icons.diagnostics.Error,
        W = icons.diagnostics.Warn,
        I = icons.diagnostics.Info,
        N = icons.diagnostics.Info,
        H = icons.diagnostics.Hint,
      }

      quicker.setup(opts)

      vim.api.nvim_create_user_command("ToggleQuickfix", function()
        quicker.toggle({ focus = true })
      end, { desc = "Toggle Quickfix" })

      vim.api.nvim_create_user_command("ToggleLoclist", function()
        quicker.toggle({ focus = true, loclist = true })
      end, { desc = "Toggle Locationlist" })

      vim.api.nvim_create_user_command("RefreshQuickfix", function()
        local win = vim.api.nvim_get_current_win()
        if quicker.is_open(win) then
          quicker.refresh(win)
        else
          quicker.refresh()
        end
      end, { desc = "Refresh Quickfix/Loclist" })
    end,
  },
}
