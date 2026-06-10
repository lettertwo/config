return {
  {
    "mikesmithgh/kitty-scrollback.nvim",
    ---@module "lazy"
    ---@param plugin LazyPlugin
    build = function(plugin)
      local function resolve(filepath)
        return vim.fs.normalize(vim.fs.joinpath(plugin.dir, filepath))
      end

      local function link(filepath)
        local filename = vim.fs.basename(filepath)
        return vim.fn.system(string.format("ln -sf %s $XDG_CONFIG_HOME/kitty/%s", resolve(filepath), filename))
      end

      link("python/kitty_scrollback_nvim.py")
      link("python/kitty_scroll_prompt.py")
      link("python/loading.py")
    end,
    cmd = { "KittyScrollbackCheckHealth" },
    event = { "User KittyScrollbackLaunch" },
    opts = {
      {
        callbacks = {
          after_launch = function()
            vim.keymap.set("n", "q", "<cmd>qa!<cr>", { desc = "Quit" })
          end,
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    optional = true,
    opts = {
      dashboard = {
        enabled = not vim.g.pager,
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    cond = not vim.g.pager,
  },
}
