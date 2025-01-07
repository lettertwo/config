return {
  {
    "folke/snacks.nvim",
    opts = {
      notifier = { level = vim.log.levels.INFO },
    },
  },

  -- scratch
  {
    "folke/snacks.nvim",
    -- stylua: ignore
    keys = {
      {"<leader>.", false},
      {"<leader>S", false},
      { "<leader>bn", function() require('snacks').scratch() end, desc = "Toggle Scratch Buffer" },
      { "<leader>bs", function() require('snacks').scratch() end, desc = "Toggle Scratch Buffer" },
      { "<leader>bS", function() require("snacks").scratch.select() end, desc = "Select Scratch Buffer" },
    },
    opts = {
      scratch = {
        win = {
          width = function()
            return vim.o.columns
          end,
          height = function()
            return math.ceil(vim.o.lines * 0.9)
          end,
          zindex = 50,
        },
      },
    },
  },

  -- profiler
  {
    {
      "folke/snacks.nvim",
      -- stylua: ignore
      keys = {
        { "<leader>bP", function() Snacks.profiler.scratch() end, desc = "Profiler Scratch Buffer" },
      },
      opts = function()
        -- Toggle the profiler
        Snacks.toggle.profiler():map("<S-C-P>")
        -- Toggle the profiler highlights
        Snacks.toggle.profiler_highlights():map("<leader>uP")
      end,
    },
    -- optional lualine component to show captured events
    -- when the profiler is running
    {
      "nvim-lualine/lualine.nvim",
      opts = function(_, opts)
        table.insert(opts.sections.lualine_x, Snacks.profiler.status())
      end,
    },
  },
}
