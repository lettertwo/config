---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local grapple_sources = {}

local function grapple_filename(item, picker)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]

  if not item.file then
    return ret
  end

  -- TODO: Compute maxwidth of tags from all items
  local maxwidth = 1

  if item.tag ~= nil then
    ret[#ret + 1] = { a(tostring(item.tag), maxwidth), "SnacksPickerSelected", virtual = true }
    ret[#ret + 1] = { " " }

    -- Relace file icon with tag icon
    if picker.opts.icons.files.enabled then
      local tagged = LazyVim.config.icons.tag
      ret[#ret + 1] = { a(tagged, vim.api.nvim_strwidth(tagged)), "SnacksPickerSelected", virtual = true }
      local file_format = require("snacks.picker.format").filename(item, picker)
      return vim.list_extend(ret, vim.list_slice(file_format, 2))
    end
  else
    ret[#ret + 1] = { a("", maxwidth) }
    ret[#ret + 1] = { " " }
    return vim.list_extend(ret, require("snacks.picker.format").filename(item, picker))
  end
end

local function grapple_buffer(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { Snacks.picker.util.align(tostring(item.buf), 3), "SnacksPickerBufNr" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { Snacks.picker.util.align(item.flags, 2, { align = "right" }), "SnacksPickerBufFlags" }
  ret[#ret + 1] = { " " }
  vim.list_extend(ret, grapple_filename(item, picker))
  return ret
end

local function select_current_buffer(picker)
  for i, item in ipairs(picker.list.items) do
    if item and item.flags and item.flags:find("%%") then
      picker.list:set_target(i)
      break
    end
  end
end

grapple_sources.buffers = {
  win = {
    input = {
      keys = {
        ["<c-x>"] = { "bufdelete_and_grapple_untag", mode = { "n", "i" } },
        ["<c-m>"] = { "grapple_toggle", mode = { "n", "i" } },
        ["<A-k>"] = { "grapple_move_up", mode = { "n", "i" } },
        ["<˚>"] = { "grapple_move_up", mode = { "n", "i" } }, -- <A-k> on macos emits "˚"
        ["<A-j>"] = { "grapple_move_down", mode = { "n", "i" } },
        ["<∆>"] = { "grapple_move_down", mode = { "n", "i" } }, -- <A-j> on macos emits "∆"
      },
    },
    list = {
      keys = {
        ["dd"] = "bufdelete_and_grapple_untag",
        ["m"] = "grapple_toggle",
        ["<A-k>"] = "grapple_move_up",
        ["<˚>"] = "grapple_move_up", -- <A-k> on macos emits "˚"
        ["<A-j>"] = "grapple_move_down",
        ["<∆>"] = "grapple_move_down", -- <A-j> on macos emits "∆"
      },
    },
  },
  format = grapple_buffer,
  on_show = select_current_buffer,
  finder = function(opts, ctx)
    local items = require("snacks.picker.source.buffers").buffers(
      vim.tbl_extend("force", opts, {
        sort_lastused = false,
      }),
      ctx
    ) --[[@as snacks.picker.finder.Item[]]

    local grapple_ok, Grapple = pcall(require, "grapple")
    if grapple_ok and Grapple then
      items = vim.tbl_map(function(item)
        item.tag = Grapple.name_or_index({ buffer = item.buf })
        return item
      end, items)
    end

    table.sort(items, function(a, b)
      if a.tag and not b.tag then
        return true
      end

      if b.tag and not a.tag then
        return false
      end

      if a.tag == b.tag and opts.sort_lastused then
        return a.info.lastused > b.info.lastused
      end

      return a.tag < b.tag
    end)

    return items
  end,
}

grapple_sources.grapple = {
  win = {
    input = {
      keys = {
        ["<c-x>"] = { "bufdelete_and_grapple_untag", mode = { "n", "i" } },
        ["<c-m>"] = { "grapple_toggle", mode = { "n", "i" } },
        ["<A-k>"] = { "grapple_move_up", mode = { "n", "i" } },
        ["<˚>"] = { "grapple_move_up", mode = { "n", "i" } }, -- <A-k> on macos emits "˚"
        ["<A-j>"] = { "grapple_move_down", mode = { "n", "i" } },
        ["<∆>"] = { "grapple_move_down", mode = { "n", "i" } }, -- <A-j> on macos emits "∆"
      },
    },
    list = {
      keys = {
        ["dd"] = "bufdelete_and_grapple_untag",
        ["m"] = "grapple_toggle",
        ["<A-k>"] = "grapple_move_up",
        ["<˚>"] = "grapple_move_up", -- <A-k> on macos emits "˚"
        ["<A-j>"] = "grapple_move_down",
        ["<∆>"] = "grapple_move_down", -- <A-j> on macos emits "∆"
      },
    },
  },
  format = grapple_filename,
  on_show = select_current_buffer,
  finder = function(opts, ctx)
    local grapple_ok, Grapple = pcall(require, "grapple")
    if not grapple_ok then
      error("grapple is required for this extension")
    end

    local items = {} ---@type snacks.picker.finder.Item[]

    local tags, err = Grapple.tags()

    if not tags then
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.notify(err, vim.log.levels.ERROR)
      return items
    end

    local app = Grapple.app()
    local quick_select = app.settings:quick_select()
    local current_buf = vim.api.nvim_get_current_buf()
    local alternate_buf = vim.fn.bufnr("#")

    for i, tag in ipairs(tags) do
      local buf = vim.fn.bufnr(tag.path)
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        local tagname = quick_select[i] and quick_select[i] or i
        if name == "" then
          name = "[No Name]" .. (vim.bo[buf].filetype ~= "" and " " .. vim.bo[buf].filetype or "")
        end
        local info = vim.fn.getbufinfo(buf)[1]
        local mark = vim.api.nvim_buf_get_mark(buf, '"')
        local flags = {
          buf == current_buf and "%" or (buf == alternate_buf and "#" or ""),
          info.hidden == 1 and "h" or (#(info.windows or {}) > 0) and "a" or "",
          vim.bo[buf].readonly and "=" or "",
          info.changed == 1 and "+" or "",
        }

        table.insert(items, {
          tag = tagname,
          flags = table.concat(flags),
          buf = buf,
          text = buf .. " " .. name,
          file = name,
          info = info,
          pos = mark[1] ~= 0 and mark or { info.lnum, 0 },
        })
      end
    end

    return ctx.filter:filter(items)
  end,
}

grapple_sources.switch = {
  multi = { "grapple", "buffers", "recent", "files" },
  matcher = {
    cwd_bonus = true, -- boost cwd matches
    frecency = true, -- use frecency boosting
    sort_empty = false, -- sort even when the filter is empty
  },
  transform = "unique_file",
  format = grapple_filename,
  on_show = select_current_buffer,
}

return grapple_sources
