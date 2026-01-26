local Util = require("util")

---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local recall_sources = {}

local function format_marked_filename(item, picker)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]

  if not item.file then
    return ret
  end

  -- TODO: Compute maxwidth of marks from all items
  local maxwidth = item.maxwidth or 1

  local path = Snacks.picker.util.path(item) or item.file
  local mark = type(item.mark) == "number" and tostring(item.mark) or item.mark

  -- Mark
  ret[#ret + 1] = { a(mark or "", maxwidth), "SnacksPickerSelected", virtual = true }
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
      icon, hl = Snacks.util.icon(name, cat, {
        fallback = picker.opts.icons.files,
      })
      if item.buftype == "terminal" then
        icon, hl = " ", "Special"
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
      local truncpath = Util.smart_shorten_path(path, pathopts)
      local base = item.titlepath or Util.title_path(path, pathopts)
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

local function format_marked_buffer(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { Snacks.picker.util.align(tostring(item.buf), 3), "SnacksPickerBufNr" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { Snacks.picker.util.align(item.flags, 2, { align = "right" }), "SnacksPickerBufFlags" }
  ret[#ret + 1] = { " " }
  vim.list_extend(ret, format_marked_filename(item, picker))
  return ret
end

---@param item snacks.picker.finder.Item
---@param ctx snacks.picker.finder.ctx
local function titlepath(item, ctx)
  ctx.meta.seen_titlepaths = ctx.meta.seen_titlepaths or {}
  local path = Snacks.picker.util.path(item) or item.file
  if path then
    local title_path = Util.title_path(path)
    local existing_item = ctx.meta.seen_titlepaths[title_path]
    if existing_item then
      if not existing_item.titlepath then
        existing_item.titlepath = Util.title_path(Snacks.picker.util.path(existing_item), { disambiguate = true })
      end
      item.titlepath = Util.title_path(path, { disambiguate = true })
    else
      ctx.meta.seen_titlepaths[title_path] = item
    end
  end
  return item
end

---@param item snacks.picker.finder.Item
---@param ctx snacks.picker.finder.ctx
local function unique_marked(item, ctx)
  local path = Snacks.picker.util.path(item) or item.file
  if not path then
    return false
  end

  ctx.meta.seen_files = ctx.meta.seen_files or {}
  ctx.meta.seen_marks = ctx.meta.seen_marks or {}

  -- If this item has a mark, deduplicate by mark letter (not file path)
  if type(item.mark) == "string" then
    if ctx.meta.seen_marks[item.mark] then
      return false -- Already seen this mark
    end
    ctx.meta.seen_marks[item.mark] = true
  -- For non-marked items, only keep if we haven't seen this file yet
  elseif ctx.meta.seen_files[path] then
    return false
  end

  ctx.meta.seen_files[path] = true

  return titlepath(item, ctx)
end

local function select_current_buffer(picker)
  for i, item in ipairs(picker.list.items) do
    if item and item.flags and item.flags:find("%%") then
      picker.list:set_target(i)
      break
    end
  end
end

recall_sources.buffers = {
  win = {
    input = {
      keys = {
        ["<c-x>"] = { "bufdelete_and_recall_unmark", mode = { "n", "i" } },
        ["<c-m>"] = { "recall_toggle", mode = { "n", "i" } },
        ["<A-k>"] = { "recall_move_up", mode = { "n", "i" } },
        ["<˚>"] = { "recall_move_up", mode = { "n", "i" } }, -- <A-k> on macos emits "˚"
        ["<A-j>"] = { "recall_move_down", mode = { "n", "i" } },
        ["<∆>"] = { "recall_move_down", mode = { "n", "i" } }, -- <A-j> on macos emits "∆"
      },
    },
    list = {
      keys = {
        ["dd"] = "bufdelete_and_recall_unmark",
        ["m"] = "recall_toggle",
        ["<A-k>"] = "recall_move_up",
        ["<˚>"] = "recall_move_up", -- <A-k> on macos emits "˚"
        ["<A-j>"] = "recall_move_down",
        ["<∆>"] = "recall_move_down", -- <A-j> on macos emits "∆"
      },
    },
  },
  ---@diagnostic disable-next-line: assign-type-mismatch
  layout = { preview = true },
  format = format_marked_buffer,
  on_show = select_current_buffer,
  transform = titlepath,
  finder = function(opts, ctx)
    local items = require("snacks.picker.source.buffers").buffers(
      vim.tbl_extend("keep", {
        sort_lastused = false,
      }, opts),
      ctx
    ) --[[@as snacks.picker.finder.Item[]]

    local recall_ok, recall_util = pcall(require, "plugins.editor.recall.util")
    local marked_files = recall_util.iter_marked_files():totable()
    if recall_ok and recall_util then
      items = vim.tbl_map(function(item)
        local file = recall_util.normalize_filepath(item.buf)
        for index, marked_file in ipairs(marked_files) do
          if file == marked_file then
            item.mark = index
            break
          end
        end
        return item
      end, items)
    end

    table.sort(items, function(a, b)
      if a.mark and not b.mark then
        return true
      end

      if b.mark and not a.mark then
        return false
      end

      ---@diagnostic disable-next-line: undefined-field
      if a.mark == b.mark and opts.sort_lastused then
        return a.info.lastused > b.info.lastused
      end

      if a.mark and b.mark then
        return a.mark < b.mark
      end

      return false
    end)

    return ctx.filter:filter(items)
  end,
}

recall_sources.recall = {
  win = {
    input = {
      keys = {
        ["<c-x>"] = { "bufdelete_and_recall_unmark", mode = { "n", "i" } },
        ["<c-m>"] = { "recall_toggle", mode = { "n", "i" } },
      },
    },
    list = {
      keys = {
        ["dd"] = "bufdelete_and_recall_unmark",
        ["m"] = "recall_toggle",
      },
    },
  },
  ---@diagnostic disable-next-line: assign-type-mismatch
  layout = { preview = true },
  format = format_marked_filename,
  on_show = select_current_buffer,
  transform = titlepath,
  finder = function(_, ctx)
    local recall_ok, recall_util = pcall(require, "plugins.editor.recall.util")
    if not recall_ok then
      error("recall is required for this source")
    end

    local items = {} ---@type snacks.picker.finder.Item[]
    local marks = recall_util.get_all_marks()

    if not marks then
      return items
    end

    local current_buf = vim.api.nvim_get_current_buf()
    local alternate_buf = vim.fn.bufnr("#")

    for _, mark in ipairs(marks) do
      local buf = vim.fn.bufnr(mark.file)
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        if name == "" then
          name = "[No Name]" .. (vim.bo[buf].filetype ~= "" and " " .. vim.bo[buf].filetype or "")
        end
        local info = vim.fn.getbufinfo(buf)[1]
        local flags = {
          buf == current_buf and "%" or (buf == alternate_buf and "#" or ""),
          info.hidden == 1 and "h" or (#(info.windows or {}) > 0) and "a" or "",
          vim.bo[buf].readonly and "=" or "",
          info.changed == 1 and "+" or "",
        }

        table.insert(items, {
          mark = mark.letter,
          flags = table.concat(flags),
          buf = buf,
          text = buf .. " " .. name,
          file = name,
          info = info,
          pos = mark.pos,
        })
      end
    end

    return ctx.filter:filter(items)
  end,
}

recall_sources.switch = {
  multi = { "recall", "buffers", "recent", "files" },
  ---@diagnostic disable-next-line: assign-type-mismatch
  layout = { preview = true },
  matcher = {
    cwd_bonus = true, -- boost cwd matches
    frecency = true, -- use frecency boosting
    sort_empty = false, -- sort even when the filter is empty
  },
  -- Custom transform: keep all marks (don't deduplicate), but deduplicate non-marked files
  -- Also prevent showing unmarked duplicates of files that have marks
  transform = unique_marked,
  format = format_marked_filename,
  on_show = select_current_buffer,
}

return recall_sources
