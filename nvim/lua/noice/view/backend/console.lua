local require = require("noice.util.lazy")

local NuiView = require("noice.view.nui")

local function debounce(ms, fn)
  local timer = vim.uv.new_timer()
  return function(...)
    local argv = { ... }
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(unpack(argv))
    end)
  end
end

---@class Console: NuiView
---@field super NuiView
---@field _routes? NoiceRouteOptions[]
---@field _lines? integer
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

    vim.notify("Added " .. #self._routes .. " console routes", "debug")
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

    vim.notify("Removed " .. count .. " console routes", "debug")
    self._routes = nil
  end
end

---@param buf number buffer number
---@param opts? {offset: number, highlight: boolean, messages?: NoiceMessage[]} line number (1-indexed), if `highlight`, then only highlight
function Console:render(buf, opts)
  Console.super.render(self, buf, opts)
  self:autoscroll()
end

Console.autoscroll = debounce(16, function(self)
  if self._nui and self._nui.bufnr and self._nui.winid then
    local cursor = vim.api.nvim_win_get_cursor(self._nui.winid)
    local autoscroll = not self._lines or cursor[1] == self._lines
    self._lines = vim.api.nvim_buf_line_count(self._nui.bufnr)
    if autoscroll then
      vim.api.nvim_win_set_cursor(self._nui.winid, { self._lines, 0 })
    end
  end
end)

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
