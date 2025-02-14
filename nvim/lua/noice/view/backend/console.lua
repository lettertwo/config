local require = require("noice.util.lazy")

local NuiView = require("noice.view.nui")

-- TODO: Figure out how to restore the previous scroll position as well
local function update_cursor(winid, cursor)
  -- Temporarily disable cursor autocmds
  local original_eventignore = vim.opt.eventignore
  vim.opt.eventignore = "all"
  vim.api.nvim_win_set_cursor(winid, cursor)
  -- Re-enable cursor autocmds
  vim.opt.eventignore = original_eventignore
end

---@class Console: NuiView
---@field super NuiView
---@field _routes? NoiceRouteOptions[]
---@field _line_count? integer
---@diagnostic disable-next-line: undefined-field
local Console = NuiView:extend("Console")

local CONSOLE_ROUTES = {
  {
    filter = { event = "msg_show", kind = { "", "echo", "echomsg" } },
    view = "console",
  },
  {
    filter = { error = true },
    view = "console",
  },
  {
    filter = { warning = true },
    view = "console",
  },
  {
    filter = { event = "notify" },
    view = "console",
  },
  {
    filter = { event = "noice", kind = { "stats", "debug" } },
    view = "console",
  },
  {
    filter = { event = "lsp", kind = "message" },
    view = "console",
  },
}

---@type NoiceViewBaseOptions | NuiSplitOptions
---@diagnostic disable-next-line: missing-fields
local CONSOLE_OPTS = {
  type = "split",
  view = "console",
  backend = "console",
  format = "details",
  enter = true,
  close = { events = { "WinClosed" } },
}

function Console:init(opts)
  return Console.super.init(self, vim.tbl_deep_extend("force", CONSOLE_OPTS, opts or {}))
end

-- TODO: add keymaps for going to a location mentioned in a stacktrace
function Console:enable()
  if not self._routes then
    self._routes = {}
    local router = require("noice.message.router")

    -- process any pending messages
    router.update()

    for route in vim.iter(CONSOLE_ROUTES):rev() do
      table.insert(self._routes, router.add(route, 1))
    end

    -- force a redraw to make sure we received all msg_show events
    vim.cmd.redraw()
    -- process messages
    router.update()

    vim.notify("Added " .. #self._routes .. " console routes", vim.log.levels.DEBUG)
  end
end

function Console:disable()
  if self._routes then
    local router = require("noice.message.router")
    local count = 0

    -- process any pending messages
    router.update()

    router._routes = vim
      .iter(router._routes)
      :filter(function(route)
        if vim.tbl_contains(self._routes, route) then
          count = count + 1
          return false
        end
        return true
      end)
      :totable()

    -- force a redraw to make sure we received all msg_show events
    vim.cmd.redraw()
    -- process messages
    router.update()

    vim.notify("Removed " .. count .. " console routes", vim.log.levels.DEBUG)
    self._routes = nil
  end
end

---@param buf number buffer number
---@param opts? {offset: number, highlight: boolean, messages?: NoiceMessage[]} line number (1-indexed), if `highlight`, then only highlight
function Console:render(buf, opts)
  if self._nui and self._nui.bufnr and self._nui.winid then
    local prev_cursor = vim.api.nvim_win_get_cursor(self._nui.winid)
    local prev_line_count = vim.api.nvim_buf_line_count(self._nui.bufnr)
    Console.super.render(self, buf, opts)
    self:update_cursor(prev_cursor, prev_line_count)
  end
end

function Console:update_cursor(prev_cursor, prev_line_count)
  -- Only autoscroll if cursor was at the last line.
  -- Otherwise, maintain previous cursor position
  if
    not prev_cursor
    or not prev_line_count
    or prev_cursor[1] == prev_line_count
    or (prev_cursor[1] == 1 and prev_cursor[2] == 0)
  then
    vim.schedule(function()
      if self._nui and self._nui.bufnr and self._nui.winid then
        update_cursor(self._nui.winid, { vim.api.nvim_buf_line_count(self._nui.bufnr), 0 })
      end
    end)
  else
    vim.schedule(function()
      if self._nui and self._nui.bufnr and self._nui.winid then
        update_cursor(self._nui.winid, prev_cursor)
      end
    end)
  end
end

function Console:show()
  self:enable()
  Console.super.show(self)
end

function Console:hide()
  self:disable()
  Console.super.hide(self)
end

function Console:reset(old, new)
  self:disable()
  Console.super.reset(self, old, new)
end

function Console:destroy()
  self:disable()
  Console.super.destroy(self)
end

---@param opts? NoiceViewBaseOptions | NuiSplitOptions
return function(opts)
  return Console(opts)
end
