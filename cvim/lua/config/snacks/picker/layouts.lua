---@module "snacks"

---@param picker snacks.Picker
local function disable_main_preview_winbar(picker)
  -- HACK: When preview is 'main', Snacks picker will create a popup win and copy winopts from the main
  -- window, including the winbar. Lualine never renders in popup windows, so we have to manually remove
  -- the winbar from the poupup that Snacks picker creates.
  if picker.preview.main and picker.preview.win then
    picker.preview.win.opts.wo.winbar = ""
    picker.preview:refresh(picker)
  end
end

---@param picker snacks.Picker
local function resize_list_to_fit_vertical(picker)
  local debounced_resize = require("snacks.util").debounce(function()
    if picker.opts.live then
      return
    end
    -- TODO: get this from opts
    local max_height = 0.6
    local list_height = math.max(math.min(#picker:items(), vim.o.lines * max_height - 10), 2)
    for _, box in ipairs(picker.layout.opts.layout) do
      if box.win == "list" then
        if box.height ~= list_height then
          box.height = list_height
          -- HACK: this is a hack to force a recalc of the layout,
          -- but the method is private and may change in the future.
          ---@diagnostic disable-next-line: invisible
          picker.layout:update()
        end
        break
      end
    end
  end, { ms = 16 })

  picker.matcher.opts.on_match = debounced_resize
  debounced_resize()
end

local jump = {
  preview = "main",
  layout = {
    backdrop = false,
    relative = "win",
    col = 0.6,
    row = 0.2,
    width = 0.3,
    min_width = 50,
    height = 0.4,
    border = "none",
    box = "vertical",
    { win = "input", height = 1, border = true, title = "{title} {live} {flags}", title_pos = "center" },
    { win = "list", border = "hpad" },
    { win = "preview", title = "{preview}", border = true },
  },
}

setmetatable(jump, {
  ---@param spec snacks.picker.Config
  __call = function(_, spec)
  return vim.tbl_deep_extend("force", {
      layout = "jump",
      on_show = function(picker)
        disable_main_preview_winbar(picker)
        resize_list_to_fit_vertical(picker)
      end,
    }, spec or {})
  end
})

local mini = {
  layout = {
    box = "vertical",
    backdrop = false,
    row = -1,
    height = 0.4,
    { win = "input", height = 1, border = true, title = " {source} {live} {flags}", title_pos = "left" },
    {
      box = "horizontal",
      { win = "list", border = "hpad" },
      { win = "preview", title = "{preview}", width = 0.6, border = "left" },
    },
  },
}

return {
  mini = mini,
  jump = jump
}
