require("config.options")

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  defaults = {
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  dev = { path = "~/.local/share/" },
  install = { colorscheme = { "laserwave", "habamax" } },
  ui = { border = "rounded" },
  checker = {
    enabled = true, -- automatically check for plugin updates
    notify = false, -- get a notification when updates are found
  },
  change_detection = {
    enabled = true, -- automatically check for config file changes and reload the ui
    notify = false, -- get a notification when changes are found
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    require("config.autocmds")
    require("config.keymaps")
  end,
})
