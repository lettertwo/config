return {
  {
    "folke/snacks.nvim",
    ---@module 'snacks'
    ---@type snacks.Config
    opts = {
      notifier = { level = vim.log.levels.INFO },
      image = {},
      indent = {
        filter = function(buf)
          return vim.g.snacks_indent ~= false
            and vim.b[buf].snacks_indent ~= false
            and vim.bo[buf].buftype == ""
            and not vim.list_contains(LazyVim.config.filetypes.ui, vim.bo[buf].filetype)
        end,
        animate = { enabled = false },
        indent = { char = "│" },
        scope = {
          enabled = true,
          only_current = true,
          char = "│",
        },
        chunk = {
          enabled = true,
          only_current = true,
          char = {
            corner_top = "╭",
            corner_bottom = "╰",
            horizontal = "─",
            vertical = "│",
            arrow = "─",
          },
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

  -- lazygit
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      local local_opts = {
        lazygit = {
          config = {
            os = {
              editPreset = nil,
              edit = 'nvim --server "$NVIM" --remote-send "q" && nvim --server "$NVIM" --remote {{filename}}',
              editAtLine = 'nvim --server "$NVIM" --remote-send "q" &&  nvim --server "$NVIM" --remote {{filename}} && nvim --server "$NVIM" --remote-send ":{{line}}<CR>"',
              -- No remote-wait support yet. See https://github.com/neovim/neovim/pull/17856
              editAtLineAndWait = "nvim +{{line}} {{filename}}",
              openDirInEditor = 'nvim --server "$NVIM" --remote-send "q" && nvim --server "$NVIM" --remote {{dir}}',
              open = 'nvim --server "$NVIM" --remote-send "q" && nvim --server "$NVIM" --remote {{filename}}',
            },
          },
        },
      }

      return vim.tbl_deep_extend("force", opts or {}, local_opts)
    end,
  },
}
