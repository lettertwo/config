return {
  -- kitty-scrollback; listed so it is installed
  -- when nvim is used as a pager for kitty scrollback (see pager.lua)
  -- TODO: migrate pager.lua
  {
    "mikesmithgh/kitty-scrollback.nvim",
    lazy = true,
    build = function()
      local function get_file_path(filename)
        return vim.fn.fnamemodify(vim.api.nvim_get_runtime_file("python/" .. filename, false)[1], ":p")
      end

      local function cp(filename)
        return vim.fn.system(string.format("cp -f %s $XDG_CONFIG_HOME/kitty/%s", get_file_path(filename), filename))
      end

      cp("kitty_scrollback_nvim.py")
      cp("kitty_scroll_prompt.py")
      cp("loading.py")
    end,
    cmd = { "KittyScrollbackGenerateKittens", "KittyScrollbackCheckHealth" },
    event = { "User KittyScrollbackLaunch" },
    config = true,
  },
}
