local Util = require("util")
local header_lines = require("plugins.dashboard.header")

local M = {}

-- Performs a deep copy of a table.
---@see vim.deepcopy
---@type fun(tbl: table): table
local deepcopy = vim.deepcopy

-- Performs a deep merge of `tbl` into `into`.
-- Note that this does not modify either table.
---@see vim.tbl_deep_extend
---@type fun(into: table, tbl: table): table
local function deepmerge(into, tbl)
  return vim.tbl_deep_extend("force", into, tbl)
end

-- Get the character length of string.
---@see strchars
---@type fun(str: string): integer
local len = vim.fn.strchars

-- Get a substring of `str` starting with the character at `start`
-- and ending after `count` characters.
---@param str string
---@param start integer
---@param count? integer
---@return string
local function substr(str, start, count)
  if count == nil then
    count = len(str) - start + 1
  end
  return vim.fn.strcharpart(str, start - 1, count)
end

-- Pads the beginning of `str` with `n` spaces.
---@param str string
---@param n integer
---@return string
local function pad_left(str, n)
  return string.rep(" ", n) .. str
end

-- Pads the end of `str` with `n` spaces.
---@param str string
---@param n integer
---@return string
local function pad_right(str, n)
  return str .. string.rep(" ", n)
end

-- Given an index and a count, generates a highlight
-- group name in the range "StartLogo1...StartLogo20"
---@param index number
---@param count number
---@return string
local function header_highlight_group(index, count)
  local ratio = 20 / count
  local group = math.min(20, math.max(1, math.floor(index * ratio + 0.5)))
  return "StartLogo" .. group
end

-- Given a list of line elements, returns an iterator that will
-- yield _single line_ elements in order, flattening nested elements
-- and splitting multiline elements.
--
-- - Group elements are flattened to the elements they contain.
-- - Multiline text elements are split into single line text elements.
-- - Padding elements with value > 1 are split into multiple padding elements.
---@param elements Element[]
---@return fun(): Button | FlatText | Padding | nil
local function iterate_line_elements(elements)
  local co = coroutine.create(function()
    for _, el in ipairs(elements) do
      if el.type == "button" then
        coroutine.yield(deepcopy(el))
      elseif el.type == "padding" then
        for _ = 1, el.val do
          coroutine.yield(deepmerge(el, { val = 1 }))
        end
      elseif el.type == "text" then
        local val = type(el.val) == "function" and el.val() or el.val
        if type(val) == "table" then
          for _, str in ipairs(val) do
            coroutine.yield(deepmerge(el, { val = str }))
          end
        else
          coroutine.yield(deepmerge(el, { val = val }))
        end
      elseif el.type == "group" then
        local val = type(el.val) == "function" and el.val() or el.val
        if type(val) == "table" then
          for nested in iterate_line_elements(val) do
            coroutine.yield(nested)
          end
        end
      end
    end
  end)
  return function()
    local status, value = coroutine.resume(co)
    if status then
      return value
    else
      return nil
    end
  end
end

-- Overwrite `line` with `new_line` starting at `start`.
-- For example: `overwrite("abc", "def", 2) -> "adef" `
---@param line string
---@param start integer
---@param new_line string
---@return string
local function overwrite(line, new_line, start)
  if start < 1 then
    error("start must be positive")
  end
  local line_len = len(line)
  if start > line_len then
    error("start exceeds length of line")
  end
  local result = substr(line, 1, start) .. new_line
  local stop = start + len(new_line) + 1
  if stop < line_len - 1 then
    result = result .. substr(line, stop)
  end
  return result
end

-- Center the string in the given window width.
---@param str string
---@param winwidth number
---@return string
local function center(str, winwidth)
  local diff = winwidth - len(str)
  local pad = math.floor(math.abs(diff) / 2)
  if diff < 0 then
    return substr(str, pad, winwidth)
  else
    return pad_left(pad_right(str, pad), pad)
  end
end

-- Given a header line element and a section line element,
-- embeds the section line in the center of the header line.
--
-- The intended effect is that the header 'wraps around' the section.
---@param header_line FlatText
---@param section_line FlatText | Button | Padding
---@return FlatText | Button
local function embed_section_line(header_line, section_line, winwidth)
  local header_val = header_line.val
  local header_opts = header_line.opts
  local oddwidth = winwidth % 2 == 1

  if section_line.type == "text" then
    ---@type string
    local text_val = section_line.val --[[ @as string ]]
    local text_opts = section_line.opts

    local start = winwidth / 2 - len(text_val) / 2
    start = oddwidth and math.floor(start) or math.ceil(start)

    local val = overwrite(header_val, text_val, start)

    -- TODO: support hl ranges (see button below)
    if type(header_opts.hl) ~= "string" or type(text_opts.hl) ~= "string" then
      error("Expected string for section.opts.hl")
    end

    -- Highlight ranges seem to count bytes, not cells or characters.
    local start_byte = #substr(val, 1, start)
    local hl = {
      { header_opts.hl, 0, start_byte },
      { text_opts.hl, start_byte, start_byte + #text_val },
      { header_opts.hl, start_byte + #text_val, #val },
    }

    return { type = "text", val = val, opts = { hl = hl } }
  elseif section_line.type == "button" then
    ---@type string
    local button_val = section_line.val --[[ @as string ]]
    local button_opts = section_line.opts
    local on_press = section_line.on_press

    -- Pad button val with width and shortcut.
    button_val = button_val .. pad_left(button_opts.shortcut, button_opts.width - len(button_val) - 1)

    local start = winwidth / 2 - len(button_val) / 2
    start = oddwidth and math.floor(start) or math.ceil(start)

    local val = overwrite(header_val, button_val, start)

    -- Highlight ranges seem to count bytes, not cells or characters.
    local start_byte = #substr(val, 1, start)
    local hl = {}
    table.insert(hl, { header_opts.hl, 0, start_byte })
    if type(button_opts.hl) == "table" then
      for _, b in ipairs(button_opts.hl) do ---@diagnostic disable-line: param-type-mismatch
        table.insert(hl, { b[1], b[2] + start_byte, b[3] + start_byte })
      end
    end
    table.insert(hl, { button_opts.hl_shortcut, start_byte + #button_val - 1, start_byte + #button_val })
    table.insert(hl, { header_opts.hl, start_byte + #button_val, #val })

    return {
      type = "button",
      val = val,
      on_press = on_press,
      opts = { hl = hl, cursor = button_opts.cursor + start, keymap = button_opts.keymap },
    }
  end

  return { type = "text", val = header_val, opts = header_opts }
end

---@param winwidth integer
---@param sections Element[]
---@return Element[]
function M.resize(winwidth, sections)
  ---@type Element[]
  local layout = {
    { type = "padding", val = 1 },
  }

  local next_section_line = iterate_line_elements(sections)

  -- Build the header section, embedding as many section lines as possible.
  for i, val in ipairs(header_lines) do
    --- @type FlatText
    local header_line = {
      type = "text",
      val = center(val, winwidth),
      opts = { hl = header_highlight_group(i, #header_lines) },
    }
    -- After line 11 we can start embedding section lines in the header.
    -- TODO: Detect when the header has room to start embedding.
    if i > 12 then
      local section_line = next_section_line()
      if section_line ~= nil then
        table.insert(layout, embed_section_line(header_line, section_line, winwidth))
      else
        table.insert(layout, header_line)
      end
    else
      table.insert(layout, header_line)
    end
  end

  -- Insert the remaining section lines into the layout.
  for section_line in next_section_line do
    table.insert(layout, section_line)
  end
  return layout
end

M.render_immediate = vim.schedule_wrap(function()
  if vim.o.filetype == "alpha" then
    require("alpha").redraw()
  end
end)

M.render = Util.debounce(16, function()
  if vim.o.filetype == "alpha" then
    require("alpha").redraw()
  end
end)

function M.setup()
  require("alpha.themes.theta").config.opts.setup() -- Adds an autocmd to refresh on dir change.
end

return M
