Config.add("folke/snacks.nvim")

local opts = {
  notifier = { level = vim.log.levels.INFO },
  image = {},
  indent = {
    filter = function(buf)
      return vim.g.snacks_indent ~= false
        and vim.b[buf].snacks_indent ~= false
        and vim.bo[buf].buftype == ""
        and not vim.list_contains(Config.filetypes.ui, vim.bo[buf].filetype)
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
  ---@type snacks.lazygit.Config
  lazygit = {
    configure = false,
    args = {
      "--use-config-file",
      vim.fs.normalize(vim.fn.stdpath("config") .. "/../lazygit/config.yml") .. "," .. vim.fs.normalize(
        vim.fn.stdpath("config") .. "/../lazygit/config-nvim.yml"
      ),
    },
    win = {
      style = "lazygit",
      zindex = 99,
      backdrop = false,
      width = 0,
      height = 0,
    },
  },
  statuscolumn = {
    left = { "sign", "mark" }, -- priority of signs on the left (high to low)
    right = { "fold", "git" }, -- priority of signs on the right (high to low)
  },
}

require("config.snacks.dashboard").config(opts)
require("config.snacks.picker").config(opts)
require("snacks").setup(opts)

local map = vim.keymap.set

-- stylua: ignore start
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete Buffer" })
map("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Delete Other Buffers" })

-- toggle options
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.inlay_hints():map("<leader>uh")

-- lazygit
if vim.fn.executable("lazygit") == 1 then
  map("n", "<leader>gg", function() Snacks.lazygit( { cwd = Config.root('git') }) end, { desc = "Lazygit (Root Dir)" })
  map("n", "<leader>gG", function() Snacks.lazygit() end, { desc = "Lazygit (cwd)" })
end
