local icons = require("config").icons

return {
  -- file explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      {
        "<leader>fE",
        function()
          require("neo-tree.command").execute({ toggle = true, dir = vim.loop.cwd() })
        end,
        desc = "File tree (cwd)",
      },
      { "<leader>E", "<leader>fE", desc = "File tree (cwd)", remap = true },
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
      filesystem = { follow_current_file = { enabled = true } },
    },
  },

  --symbols outline
  {
    "simrat39/symbols-outline.nvim",
    cmd = { "SymbolsOutline", "SymbolsOutlineOpen" },
    event = "VeryLazy",
    keys = {
      { "<leader>S", "<cmd>SymbolsOutline<cr>", desc = "Symbols outline" },
    },
    opts = {},
  },

  -- search/replace in multiple files
  {
    "windwp/nvim-spectre",
    -- stylua: ignore
    keys = {
      { "<leader>sr", function() require("spectre").open() end, desc = "Replace in files (Spectre)" },
    },
  },

  -- easily jump to any location and enhanced /, ?, f, t, F, T motions
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    -- stylua: ignore
    keys = {
      { "s", mode = { "o", "x" }, function() require("flash").jump() end, desc = "Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
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
        ["<leader>\\"] = { name = "+terminals" },
        ["<leader><tab>"] = { name = "+tabs" },
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>bp"] = { name = "+pin" },
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

  -- sticky buffers
  {
    "stevearc/stickybuf.nvim",
    event = "VeryLazy",
    cmd = { "PinBuffer", "PinBuftype", "PinFiletype", "Unpin" },
    keys = {
      { "<leader>bpb", "<cmd>PinBuffer<cr>", desc = "Pin buffer" },
      { "<leader>bpt", "<cmd>PinBuftype<cr>", desc = "Pin buffer type" },
      { "<leader>bpf", "<cmd>PinFiletype<cr>", desc = "Pin fileytype" },
      { "<leader>bpu", "<cmd>Unpin<cr>", desc = "Unpin buffer" },
    },
    -- TODO: configure sticky buffers for symbols outline, neotree, toggleterm, trouble, etc.
    opts = {},
  },
}
