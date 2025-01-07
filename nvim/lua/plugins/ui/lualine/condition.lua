local Util = require("util")
local filetypes = require("lazyvim.config").filetypes

-- A callable type that can be used as a conditional callback.
-- It can be sequenced with other conditions via the `+` operator.
---@class Condition
---@operator add(Condition | fun(): boolean): Condition
---@overload fun(): boolean
---@field protected callback fun(): boolean
local Condition = {}

-- Create a new condition from a callback.
---@param callback (fun(): boolean)
---@return self
function Condition.new(callback)
  assert(callback, "Condition must have a callback")

  local condition = {}
  local meta = Condition
  if not Util.is_callable(callback) then
    error("callback must be callable")
  else
    condition.callback = callback
  end

  return setmetatable(condition, {
    __index = meta,
    __add = meta.add,
    __call = meta.call,
  })
end

-- Combines two conditions into a single condition.
--
-- This is normally invoked by using the `+` operator, not called directly.
--
---@protected
---@param left Condition | fun(): boolean
---@param right Condition | fun(): boolean
---@return self
function Condition.add(left, right)
  if Util.is_callable(right) and Util.is_callable(left) then
    return Condition.new(function()
      return left() and right()
    end)
  end
  error("When combining conditions, both must be callable")
end

-- Calls the condition's callback.
--
-- This is normally invoked by using the `()` operator, not called directly.
--
---@protected
function Condition:call()
  return self.callback()
end

local WINDOW_WIDTH_LIMIT = 70

local M = {}

M.Condition = Condition

M.visible_for_width = Condition.new(function()
  return vim.fn.winwidth(0) > WINDOW_WIDTH_LIMIT
end)

M.visible_for_filetype = Condition.new(function()
  return not vim.tbl_contains(filetypes.ui, vim.bo.filetype)
end)

-- Only show tabline if we have more than one tab open.
M.tabline_active = Condition.new(function()
  return #vim.api.nvim_list_tabpages() > 1
end)

return M
