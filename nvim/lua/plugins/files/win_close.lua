local M = {}

--- @type table<number, boolean>
local open_windows = {}

--- @type number | nil
local auid = nil

--- @param args {match : string}
local function handle_win_closed(args)
  local win_id = tonumber(args.match)
  -- if the window is not a MiniFiles window, do nothing
  if win_id == nil or not open_windows[win_id] then
    return
  end
  M.close(win_id)
end

--- keep track of open windows so we can gracefully close MiniFiles
--- when they are closed externally, e.g., via `vim.api.nvim_win_close`.
--- @param win_id number
function M.open(win_id)
  open_windows[win_id] = true
  if auid == nil then
    -- autocmd to close files gracefully when the last window is closed
    auid = vim.api.nvim_create_autocmd("WinClosed", {
      pattern = "*",
      callback = handle_win_closed,
    })
  end
end

--- keep track of externally closed windows, e.g., via `vim.api.nvim_win_close`
--- so we can gracefully close MiniFiles when the last one is closed.
--- @param win_id number
function M.close(win_id)
  open_windows[win_id] = nil
  if vim.tbl_isempty(open_windows) then
    if auid ~= nil then
      vim.api.nvim_del_autocmd(auid)
      auid = nil
    end
    pcall(MiniFiles.close)
  end
end

return M
