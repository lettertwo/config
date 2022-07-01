local Dashboard = {}

Dashboard.config = function()
  if not lvim.builtin.alpha.active then
    return
  end

  lvim.builtin.alpha.mode = "dashboard"

  lvim.builtin.alpha.dashboard.section.buttons.entries = {
    { "n", "  New File", "<CMD>ene!<CR>" },
    { "l", "  Last Session", '<CMD>SessionLoadLast<CR>' },
    { "s", "  Load Session", '<CMD>SessionLoad<CR>' },
    { "S", "  Recent Sessions", "<CMD>Telescope persisted<CR>" },
    { "p", "  Recent Projects", "<CMD>Telescope projects<CR>" },
    { "r", "  Recently Used Files", "<CMD>Telescope oldfiles<CR>" },
    { "f", "  Find File", "<CMD>Telescope find_files hidden=true path_display=smart<CR>" },
    { "w", "  Find Word", "<CMD>Telescope live_grep path_display=smart<CR>" },
    { "u", "  Update Plugins", "<CMD>PackerSync<CR>" },
    {
      "c",
      "  Configuration",
      "<CMD>Telescope find_files cwd=$LUNARVIM_CONFIG_DIR prompt_title=User\\ Config\\ Files<CR>",
    },
    { "q", "  Quit", "<CMD>qa<CR>" },
  }

  local text = require("lvim.interface.text")
  -- local plugins = " " .. #vim.tbl_keys(packer_plugins)
  local version = vim.version()
  local nvim_version = " " .. version.major .. "." .. version.minor .. "." .. version.patch
  local lvim_version = " " .. require("lvim.utils.git").get_lvim_version()

  lvim.builtin.alpha.dashboard.section.footer.val = text.align_center({ width = 0 }, {
    "",
    -- plugins,
    nvim_version,
    lvim_version,
  }, 0.5)
end

return Dashboard
