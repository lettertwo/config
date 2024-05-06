local filetype = require("plugins.lualine.components").filetype
local Util = require("util")

local Buffer = require("lualine.utils.class"):extend()

---@class BufferProps
---@field current boolean?
---@field aftercurrent boolean?
---@field beforecurrent boolean?
---@field first boolean?
---@field last boolean?

---@class BufferOpts
---@field bufnr number
---@field tag_id number?
---@field tag_name string?
---@field options table
---@field highlights table

function Buffer:init(opts)
  assert(opts.bufnr, "Cannot create Buffer without bufnr")
  self.bufnr = opts.bufnr
  self.tag_id = opts.tag_id
  self.tag_name = opts.tag_name
  self.options = opts.options
  self.highlights = opts.highlights

  if vim.api.nvim_buf_is_valid(self.bufnr) then
    self.file = require("lualine.utils.utils").stl_escape(vim.api.nvim_buf_get_name(self.bufnr))
    self.buftype = vim.api.nvim_get_option_value("buftype", { buf = self.bufnr })
    self.filetype = vim.api.nvim_get_option_value("filetype", { buf = self.bufnr })
    self.modified = vim.api.nvim_get_option_value("modified", { buf = self.bufnr })
    self.icon = require("nvim-web-devicons").get_icon(self.file, vim.fn.expand("#" .. self.bufnr .. ":e"))
  end
end

---@param props BufferProps
function Buffer:name(props)
  local name = {}

  if self.tag_name then
    table.insert(name, self.tag_name)
  elseif self.tag_id then
    table.insert(name, tostring(self.tag_id))
  end

  if props.current then
    table.insert(name, self.icon)
    table.insert(name, Util.title_path(self.file))
  elseif #name == 0 then
    table.insert(name, Util.title_path(self.file))
  end

  return table.concat(name, " ")
end

function Buffer:is_current()
  return self.bufnr == vim.api.nvim_get_current_buf()
end

---returns line configured for handling mouse click
---@param name string
---@return string
function Buffer:configure_mouse_click(name)
  if not _G.SwitchBuffer then
    function _G.SwitchBuffer(bufnr, _, mousebutton)
      if mousebutton == nil or mousebutton == "l" then
        vim.api.nvim_set_current_buf(bufnr)
      end
    end
  end

  return string.format("%%%s@v:lua.SwitchBuffer@%s%%X", self.bufnr, name)
end

---apply separator before current buffer
---@param props BufferProps
---@return string
function Buffer:separator_before(props)
  if props.current or props.aftercurrent then
    return "%Z{" .. self.options.section_separators.left .. "}"
  else
    return self.options.component_separators.left
  end
end

---apply separator after current buffer
---@param props BufferProps
---@return string
function Buffer:separator_after(props)
  if props.current or props.beforecurrent then
    return "%z{" .. self.options.section_separators.right .. "}"
  else
    return self.options.component_separators.right
  end
end

---adds spaces to left and right
function Buffer.apply_padding(str, padding)
  local l_padding, r_padding = 1, 1
  if type(padding) == "number" then
    l_padding, r_padding = padding, padding
  elseif type(padding) == "table" then
    l_padding, r_padding = padding.left or 0, padding.right or 0
  end
  return string.rep(" ", l_padding) .. str .. string.rep(" ", r_padding)
end

---@param props BufferProps
---@return string
function Buffer:render(props)
  local name = self:name(props)

  name = Buffer.apply_padding(name, self.options.padding)
  self.len = vim.fn.strchars(name)

  -- setup for mouse clicks
  local line = self:configure_mouse_click(name)

  -- apply highlight
  line = require("lualine.highlight").component_format_highlight(
    self.highlights[(props.current and "active" or "inactive")]
  ) .. line

  -- apply separators
  if self.options.self.section < "x" and not props.first then
    local sep_before = self:separator_before(props)
    line = sep_before .. line
    self.len = self.len + vim.fn.strchars(sep_before)
  elseif self.options.self.section >= "x" and not props.last then
    local sep_after = self:separator_after(props)
    line = line .. sep_after
    self.len = self.len + vim.fn.strchars(sep_after)
  end

  return line
end

---@param section string
---@param is_active boolean
---@return string hl name
local function get_hl(section, is_active)
  local highlight = require("lualine.highlight")
  local suffix = is_active and highlight.get_mode_suffix() or "_inactive"
  local section_redirects = {
    lualine_x = "lualine_c",
    lualine_y = "lualine_b",
    lualine_z = "lualine_a",
  }
  if section_redirects[section] then
    section = highlight.highlight_exists(section .. suffix) and section or section_redirects[section]
  end
  return section .. suffix
end

local default_options = {}

local M = require("lualine.component"):extend()

function M:init(options)
  M.super.init(self, options)
  self.options = vim.tbl_deep_extend("keep", self.options or {}, default_options)
  self.highlights = {
    active = self:create_hl(function()
      return get_hl("lualine_" .. options.self.section, true)
    end, "active"),
    inactive = self:create_hl(get_hl("lualine_" .. options.self.section, false), "inactive"),
  }
end

function M:buffers()
  local buffers = {}
  local bufnr = vim.api.nvim_get_current_buf()
  local found_current = false

  if package.loaded["grapple"] then
    local Grapple = require("grapple")
    local app = Grapple.app()
    local quick_select = app.settings:quick_select()
    local tags = Grapple.tags()
    if tags then
      local current = Grapple.find({ buffer = bufnr })
      for i, tag in ipairs(tags) do
        table.insert(
          buffers,
          Buffer:new({
            bufnr = vim.fn.bufnr(tag.path),
            options = self.options,
            highlights = self.highlights,
            tag_id = quick_select[i] and quick_select[i] or i,
            tag_name = tag.name,
          })
        )
        if current and current.path == tag.path then
          found_current = true
        end
      end
    end
  end

  if not found_current then
    table.insert(
      buffers,
      Buffer:new({
        bufnr = bufnr,
        options = self.options,
        highlights = self.highlights,
      })
    )
  end

  return buffers
end

function M:update_status()
  local data = {}
  local buffers = self:buffers()
  local current = 0

  for i, buffer in ipairs(buffers) do
    if current == 0 and buffer:is_current() then
      current = i
    end

    table.insert(
      data,
      buffer:render({
        current = i == current,
        beforecurrent = i == current - 1,
        aftercurrent = i == current + 1,
        first = i == 1,
        last = i == #buffers,
      })
    )
  end

  return table.concat(data)
end

function M:draw()
  self.status = ""
  self.applied_separator = ""

  -- if not filetype.cond() then
  --   return
  -- end
  if self.options.cond ~= nil and self.options.cond() ~= true then
    return self.status
  end
  local status = self:update_status()
  if type(status) == "string" and #status > 0 then
    self.status = status
    self:apply_section_separators()
    self:apply_separator()
  end
  return self.status
end

return M
