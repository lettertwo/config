return {
  {
    "folke/snacks.nvim",
    ---@module 'snacks'
    ---@type snacks.Config
    opts = {
      notifier = { level = vim.log.levels.INFO },
      indent = {
        filter = function(buf)
          return vim.g.snacks_indent ~= false
            and vim.b[buf].snacks_indent ~= false
            and vim.bo[buf].buftype == ""
            and not vim.list_contains(require("lazyvim.config").filetypes.ui, vim.bo[buf].filetype)
        end,
        animate = { enabled = false },
        indent = { char = "┆" },
        scope = {
          enabled = true,
          only_current = true,
          char = "┆",
        },
        chunk = {
          enabled = true,
          only_current = true,
          char = {
            corner_top = "╭",
            corner_bottom = "╰",
            horizontal = "╌",
            vertical = "┆",
            arrow = "╌",
          },
        },
      },
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
