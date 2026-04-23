---@module "snacks"

---@type snacks.picker.format
local function title_path(item, picker)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]

  if not item.file then
    return ret
  end

  local path = Snacks.picker.util.path(item) or item.file
  local mark = type(item.mark) == "number" and tostring(item.mark) or item.mark

  -- Mark
  ret[#ret + 1] = { a(mark or "", 1), "SnacksPickerSelected", virtual = true }
  ret[#ret + 1] = { " " }

  -- File icon
  if picker.opts.icons.files.enabled then
    local icon, hl
    if mark ~= nil then
      icon, hl = LazyVim.config.icons.tag, "@tag"
    else
      local name, cat = path, (item.dir and "directory" or "file")
      if item.buf and vim.api.nvim_buf_is_loaded(item.buf) and vim.bo[item.buf].buftype ~= "" then
        name = vim.bo[item.buf].filetype
        cat = "filetype"
      end
      if item.buftype == "terminal" then
        icon, hl = " ", "Special"
      elseif name then
        icon, hl = Snacks.util.icon(name, cat, {
          fallback = picker.opts.icons.files,
        })
      end
      if item.dir and item.open then
        icon = picker.opts.icons.files.dir_open
      end
    end
    icon = Snacks.picker.util.align(icon, picker.opts.formatters.file.icon_width or 2)
    ret[#ret + 1] = { icon, hl, virtual = true }
  end

  local base_hl = item.dir and "SnacksPickerDirectory" or "SnacksPickerFile"
  local function is(prop)
    local it = item
    while it do
      if it[prop] then
        return true
      end
      it = it.parent
    end
  end

  if is("ignored") then
    base_hl = "SnacksPickerPathIgnored"
  elseif item.filename_hl then
    base_hl = item.filename_hl
  elseif is("hidden") then
    base_hl = "SnacksPickerPathHidden"
  end
  local dir_hl = "SnacksPickerDir"

  ret[#ret + 1] = {
    "",
    resolve = function(max_width)
      local pathopts = {
        cwd = picker:cwd(),
        target_width = math.max(max_width, picker.opts.formatters.file.min_width or 20),
      }
      local truncpath = Config.smart_shorten_path(path, pathopts)
      local base = item.titlepath or Config.title_path(path, pathopts)
      local dir = truncpath:sub(1, #truncpath - #base)

      local resolved = {} ---@type snacks.picker.Highlight[]
      if base and dir then
        if picker.opts.formatters.file.filename_first then
          resolved[#resolved + 1] = { base, base_hl, field = "file" }
          resolved[#resolved + 1] = { " " }
          resolved[#resolved + 1] = { dir, dir_hl, field = "file" }
        else
          resolved[#resolved + 1] = { dir .. "/", dir_hl, field = "file" }
          resolved[#resolved + 1] = { base, base_hl, field = "file" }
        end
      else
        resolved[#resolved + 1] = { truncpath, base_hl, field = "file" }
      end
      return resolved
    end,
  }

  -- Add position info
  if item.pos and item.pos[1] > 0 then
    ret[#ret + 1] = { ":", "SnacksPickerDelim" }
    ret[#ret + 1] = { tostring(item.pos[1]), "SnacksPickerRow" }
    if item.pos[2] > 0 then
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { tostring(item.pos[2]), "SnacksPickerCol" }
    end
  end
  ret[#ret + 1] = { " " }

  -- Add link target info
  if item.type == "link" then
    local real = vim.loop.fs_realpath(item.file)
    local broken = not real
    real = real or vim.loop.fs_readlink(item.file)
    if real then
      ret[#ret + 1] = { "-> ", "SnacksPickerDelim" }
      ret[#ret + 1] =
        { Snacks.picker.util.truncpath(real, 20), broken and "SnacksPickerLinkBroken" or "SnacksPickerLink" }
      ret[#ret + 1] = { " " }
    end
  end

  return ret
end

return title_path
