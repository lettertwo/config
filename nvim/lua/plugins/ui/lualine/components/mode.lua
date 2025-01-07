local M = require("lualine.component"):extend()

function M:update_status()
  -- TODO: Look at https://github.com/Iron-E/nvim-libmodal#lualinenvim
  -- for example of how to do arbitrary modes with themes.
  if vim.b.visual_multi == 1 then
    local vm = vim.b.VM_Selection
    if vm then
      return "V-MULTI " .. vm.Vars.index + 1 .. "/" .. #vm.Regions
    else
      return "V-MULTI"
    end
  end
  local hydra_ok, hydra = pcall(require, "hydra.statusline")
  if hydra_ok and hydra.is_active() then
    local name = hydra.get_name()
    local color = hydra.get_color()

    if name ~= nil then
      return name
    end
  end

  return require("lualine.utils.mode").get_mode()
end

return M
