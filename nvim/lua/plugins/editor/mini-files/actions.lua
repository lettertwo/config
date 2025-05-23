local M = {}

local MiniFiles = require("mini.files")

local function map_split(direction)
  return function()
    -- if current selection is not a file, do nothing.
    if MiniFiles.get_fs_entry().fs_type ~= "file" then
      return
    end

    local win_id = MiniFiles.get_explorer_state().target_window
    if win_id ~= nil then
      -- Make new window and set it as target
      local new_target_window = vim.api.nvim_get_current_win()
      vim.api.nvim_win_call(win_id, function()
        vim.cmd(direction .. " split")
        new_target_window = vim.api.nvim_get_current_win()
      end)
      MiniFiles.set_target_window(new_target_window)
      MiniFiles.go_in({ close_on_file = true })
      MiniFiles.close()
    end
  end
end

M.split = map_split("belowright horizontal")
M.vsplit = map_split("belowright vertical")

function M.files_set_cwd(path)
  -- Works only if cursor is on the valid file system entry
  local cur_entry_path = MiniFiles.get_fs_entry().path
  local cur_directory = vim.fs.dirname(cur_entry_path)
  vim.fn.chdir(cur_directory)
end

local show_dotfiles = true
-- stylua: ignore start
local filter_show = function() return true end
local filter_hide = function(fs_entry) return not vim.startswith(fs_entry.name, ".") end
-- stylua: ignore end

function M.toggle_dotfiles()
  show_dotfiles = not show_dotfiles
  local new_filter = show_dotfiles and filter_show or filter_hide
  MiniFiles.refresh({ content = { filter = new_filter } })
end

function M.open_cwd()
  MiniFiles.open(nil, false)
end

function M.open_buffer()
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" then
    MiniFiles.open(nil, false)
  else
    MiniFiles.open(buf_name, false)
  end
end

function M.close()
  return MiniFiles.close()
end

function M.reveal_in_finder()
  local entry = MiniFiles.get_fs_entry()
  if entry ~= nil and entry.path ~= nil then
    if vim.fn.system("open -R " .. entry.path) then
      MiniFiles.close()
    end
  end
end

function M.toggle_tag()
  local grapple_ok, Grapple = pcall(require, "grapple")
  if grapple_ok then
    local entry = MiniFiles.get_fs_entry()
    if entry ~= nil and entry.path ~= nil then
      Grapple.toggle({ path = entry.path })
      local new_filter = show_dotfiles and filter_show or filter_hide
      MiniFiles.refresh({ content = { filter = new_filter } })
    end
  else
    vim.notify("grapple not found", vim.log.levels.WARN)
  end
end

return M
