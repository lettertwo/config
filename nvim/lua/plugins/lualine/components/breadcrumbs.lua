local M = require("lualine.component"):extend()
-- local filetypes = require("config").filetypes

-- local function visible_for_filetype()
--   return not vim.tbl_contains(filetypes.ui, vim.bo.filetype)
-- end
--
-- local function excludes()
--   if not visible_for_filetype() then
--     vim.opt_local.winbar = nil
--     return true
--   end
--   return false
-- end
--
function M:update_status()
  -- if excludes() then
  --   return
  -- end

  if not package.loaded["dropbar"] then
    return
  end

  -- TODO: update opts.menu.win_configs.col to match the size of the filepath section.
  -- from https://github.com/Bekaboo/dropbar.nvim/issues/19#issuecomment-1574760272
  return "%{%v:lua.dropbar.get_dropbar_str()%}"
end

return M
