local Util = require("util")

local version, commit = unpack(vim.split(vim.fn.execute("version"):gsub(".*%sv([%w%p]+)\n.*", "%1"), "+"))

local M = {
  version = version,
  commit = commit,
}

-- Get the window that is displaying the alpha buffer.
---@return integer | nil
function M.alpha_win()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "alpha" then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
          return win
        end
      end
    end
  end
end

M.dots = {
  "⠋ ",
  "⠙ ",
  "⠹ ",
  "⠸ ",
  "⠼ ",
  "⠴ ",
  "⠦ ",
  "⠧ ",
  "⠇ ",
  "⠏ ",
}

-- A stateful button that can show a count of available updates.
-- The button will render in a pending state initially.
-- When called with a positive count, it will update its state
-- and call the given callback.
--
---@param shortcut string
---@param icon string
---@param label string
---@param keybind? string optional
---@param keybind_opts? table optional
---@parm cb? fun() optional callback to call when the pending state ticks
function M.button(shortcut, icon, label, keybind, keybind_opts, cb)
  local phase = 1
  local el = require("alpha.themes.dashboard").button(shortcut, M.dots[phase] .. " " .. label, keybind, keybind_opts)

  local dispose_tick

  if type(cb) == "function" then
    dispose_tick = Util.interval(60, function()
      phase = phase % #M.dots + 1
      el.val = M.dots[phase] .. " " .. label
      cb()
    end)
  end

  setmetatable(el, {
    __call = function(_, count, cb)
      if dispose_tick then
        dispose_tick()
        dispose_tick = nil
      end
      if count ~= nil then
        if count == 0 then
          el.val = icon .. " " .. label
        else
          el.val = icon .. " " .. label .. " " .. count .. ((count > 1) and " updates available" or " update available")
          el.opts.hl = "SpecialComment"
        end
        if type(cb) == "function" then
          cb()
        end
      end
    end,
  })

  return el
end

return M
