local icons = require("config").icons

return {
  -- file explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = "Neotree",
    keys = {
      {
        "<leader>fE",
        function()
          require("neo-tree.command").execute({ toggle = true, dir = vim.loop.cwd() })
        end,
        desc = "File tree (cwd)",
      },
      { "<leader>E", "<leader>fE", desc = "File tree (cwd)", remap = true },
      -- { "<leader>T", "<cmd>Neotree float buffers<cr>", desc = "Buffer tree" },
      { "<leader>gg", "<cmd>Neotree float git_status<cr>", desc = "Git tree (cwd)" },
      { "<leader>gG", "<cmd>Neotree float git_status<cr>", desc = "Git tree (root)" },
    },
    init = function()
      vim.g.neo_tree_remove_legacy_commands = 1
      if vim.fn.argc() == 1 then
        local stat = vim.loop.fs_stat(vim.fn.argv(0))
        if stat and stat.type == "directory" then
          require("neo-tree")
        end
      end
    end,
    opts = {
      default_component_configs = { git_status = { symbols = vim.tbl_extend("force", {}, icons.diff, icons.git) } },
      filesystem = { follow_current_file = true },
    },
  },

  -- search/replace in multiple files
  {
    "windwp/nvim-spectre",
    -- stylua: ignore
    keys = {
      { "<leader>sr", function() require("spectre").open() end, desc = "Replace in files (Spectre)" },
    },
  },

  -- easily jump to any location and enhanced f/t motions for Leap
  {
    "ggandor/leap.nvim",
    event = "VeryLazy",
    opts = {
      -- max_phase_one_targets = 0,
      highlight_unlabeled_phase_one_targets = true,
      equivalence_classes = {
        " \t\r\n",
        "([{<",
        ")]}>",
        ".,;:!?'",
        "`'\"",
      },
      special_keys = {
        repeat_search = "<enter>",
        next_phase_one_target = "<enter>",
        next_target = "<enter>",
        prev_target = "<s-enter>",
        next_group = "<space>",
        prev_group = "<s-space>",
        multi_accept = "<enter>",
        multi_revert = "<backspace>",
      },
    },
    keys = {
      { "f", "<Plug>(leap-forward-to)", mode = { "n", "x", "o" }, desc = "Leap forward to" },
      { "F", "<Plug>(leap-backward-to)", mode = { "n", "x", "o" }, desc = "Leap backward to" },
      { "t", "<Plug>(leap-forward-till)", mode = { "n", "x", "o" }, desc = "Leap forward till" },
      { "T", "<Plug>(leap-backward-till)", mode = { "n", "x", "o" }, desc = "Leap backward till" },
      { "gw", "<Plug>(leap-from-window)", mode = { "n", "x", "o" }, desc = "Leap from window" },
    },
    config = function(_, opts)
      local leap = require("leap")
      for k, v in pairs(opts) do
        leap.opts[k] = v
      end
    end,
  },

  -- which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      plugins = { spelling = true },
      window = { border = "single" },
      show_help = false,
      show_keys = false,
      key_labels = { ["<leader>"] = "SPC" },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      wk.register({
        mode = { "n", "v" },
        ["g"] = { name = "+goto" },
        ["]"] = { name = "+next" },
        ["["] = { name = "+prev" },
        ["<leader><tab>"] = { name = "+tabs" },
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>d"] = { name = "+debug" },
        ["<leader>f"] = { name = "+file/find" },
        ["<leader>g"] = { name = "+git" },
        ["<leader>l"] = { name = "+lsp" },
        ["<leader>q"] = { name = "+quit/session" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>se"] = { name = "+emoji" },
        ["<leader>sn"] = { name = "+noice" },
        ["<leader>u"] = { name = "+ui" },
        ["<leader>x"] = { name = "+diagnostics/quickfix" },
      })
    end,
  },

  -- buffer remove
  {
    "echasnovski/mini.bufremove",
    -- stylua: ignore
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete Buffer" },
      { "<leader>bD", function() require("mini.bufremove").delete(0, true) end, desc = "Delete Buffer (Force)" },
    },
  },
}
