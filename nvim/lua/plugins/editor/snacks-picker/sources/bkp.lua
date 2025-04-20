---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local sources = {}

local format = require("plugins.editor.snacks-picker.format")

---@alias FindScope 'cwd' | 'root' | 'workspace'  | 'package'
---@alias FindSource 'files' | 'packages' | 'node_modules' | 'plugins'

---@class PickerConfigWithScope: snacks.picker.Config
---@field scope FindScope?

local WORKSPACE_PATTERNS = { "lua", "yarn.lock", "package-lock.json", "pnpm-lock.yaml", "bun.lockb" }
local PACKAGE_PATTERNS = { "package.json", "Cargo.toml" }

---@param scope_or_opts FindScope | PickerConfigWithScope
---@param opts snacks.picker.Config?
---@return string? cwd
local function get_scope_dir(scope_or_opts, opts)
  local scope = type(scope_or_opts) == "string" and scope_or_opts or scope_or_opts.scope

  if scope == nil then
    return nil
  end

  local resolved
  if scope == "root" then
    resolved = LazyVim.root.git()
  elseif scope == "workspace" then
    resolved = LazyVim.root.detectors.lsp(0)[1] or LazyVim.root.detectors.pattern(0, WORKSPACE_PATTERNS)[1]
  elseif scope == "package" then
    -- TODO: resolve relative opts.cwd, if it exists
    resolved = LazyVim.root.detectors.pattern(0, PACKAGE_PATTERNS)[1]
      or LazyVim.root.detectors.pattern(0, WORKSPACE_PATTERNS)[1]
  else
    resolved = opts and opts.cwd or LazyVim.root.detectors.cwd()[1]
  end

  return resolved or LazyVim.root.get()
end

---@param source string
---@param scope FindScope?
---@param cwd string?
---@return string
local function get_title(source, scope, cwd)
  local title = source:gsub("^%l", string.upper)
  if scope ~= nil then
    title = title .. " in " .. scope
  end
  if cwd ~= nil then
    title = title .. " [" .. require("util").smart_shorten_path(cwd) .. "]"
  end
  return title
end

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
  picker.matcher.opts.on_match = require("snacks.util").debounce(function()
    if picker.opts.live then
      return
    end

    -- TODO: get this from opts
    local max_height = 0.6
    local height = math.min(max_height, (#picker:items() + 3) / vim.o.lines)
    if picker.layout.opts.layout.height ~= height then
      picker.layout.opts.layout.height = height
      -- FIXME: this is a hack to force a recalc of the layout, but there are 2 problems:
      -- 1. it causes a flicker of the preview window
      -- 2. the method is private and may change in the future
      ---@diagnostic disable-next-line: invisible
      picker.layout:update()
    end
  end, { ms = 16 })
end

sources.git_status = {
  layout = {
    preview = true,
  },
}

sources.git_diff = {
  layout = {
    preview = true,
  },
}

sources.files = {
  ---@param opts PickerConfigWithScope
  config = function(opts)
    local scope = opts and opts.scope
    local cwd = get_scope_dir(opts)
    opts.title = get_title("files", scope, cwd)
    if scope or cwd then
      opts.cwd = cwd
    end
    return opts
  end,
}

sources.recent = {
  ---@param opts PickerConfigWithScope
  config = function(opts)
    local scope = opts and opts.scope
    local cwd = get_scope_dir(opts)
    opts.title = get_title("recent", scope, cwd)
    if scope or cwd then
      opts.cwd = cwd
      opts.filter = vim.tbl_deep_extend("force", opts.filter or {}, {
        cwd = cwd,
      })
    end
    return opts
  end,
}

sources.buffers = {
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
  format = format.grapple_buffer,
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

sources.grapple = {
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
  format = format.grapple_filename,
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

    return ctx.filter:filter(items)
  end,

  ---@param opts PickerConfigWithScope
  config = function(opts)
    local scope = opts and opts.scope
    local cwd = get_scope_dir(opts)
    opts.title = get_title("grapple", scope, cwd)
    if scope or cwd then
      opts.cwd = cwd
      opts.filter = vim.tbl_deep_extend("force", opts.filter or {}, {
        cwd = cwd,
      })
    end
    return opts
  end,
}

sources.switch = {
  multi = { "grapple", "buffers", "recent", "files" },
  matcher = {
    cwd_bonus = true, -- boost cwd matches
    frecency = true, -- use frecency boosting
    sort_empty = false, -- sort even when the filter is empty
  },
  transform = "unique_file",
  format = format.grapple_filename,
  ---@param opts PickerConfigWithScope
  config = function(opts)
    local scope = opts and opts.scope
    local cwd = get_scope_dir(opts)
    opts.title = get_title("switch", scope, cwd)
    if scope or cwd then
      opts.cwd = cwd
      opts.filter = vim.tbl_deep_extend("force", opts.filter or {}, {
        cwd = cwd,
      })
    end
    return opts
  end,
}

sources.directories = {
  finder = function(opts, ctx)
    local cwd = ctx.picker.opts.cwd or opts.cwd or vim.fn.getcwd()
    local max_depth = ctx.picker.opts.max_depth or 1
    if vim.fn.isdirectory(cwd) ~= 1 then
      return {}
    end

    local cmd = "fd"
    -- TODO: add args for opts like hidden, exclude, etc.
    -- See ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/source/files
    local args = {
      "--type",
      "d",
      "--color=never",
      "--max-depth",
      max_depth,
      ".",
      cwd,
    }

    return require("snacks.picker.source.proc").proc({
      opts,
      {
        notify = false,
        cmd = cmd,
        args = args,
        transform = function(item)
          if not item.text then
            return false
          end
          item.cwd = ctx.picker.opts.cwd
          item.file = item.text
          item._path = vim.fs.abspath(item.text)
          item.dirname = vim.fs.dirname(item.text)
          item.basename = vim.fs.basename(item.dirname)
          item.dir = true
        end,
      },
    }, ctx)
  end,

  format = "file",
  preview = "directory",
  layout = {
    preview = true,
  },
  confirm = "explore",
}

-- TODO: use yarn info or something instead?
sources.node_modules = vim.tbl_extend("force", sources.directories, {
  config = function(opts)
    -- local package_dir = LazyVim.root.detectors.pattern(0, "package.json")[1]
    local package_dir = LazyVim.root.git()
    local cwd = package_dir or vim.fn.getcwd()
    opts.cwd = vim.fs.joinpath(cwd, "node_modules")
    opts.max_depth = 2
    opts.transform = function(item)
      -- exclude @namespace dirs
      if item.basename:match("^@[^/]+$") then
        return false
      end
      -- label items with namespace
      local namespace = item.dirname:match(".*(@[^/]+)/?.*$")
      if namespace then
        item.namespace = namespace
        item.label = namespace
      end
    end
  end,
})

sources.plugins = vim.tbl_extend("force", sources.directories, {
  config = function(opts)
    opts.cwd = require("lazy.core.config").options.root
  end,
  transform = function(item)
    local plugins = require("lazy.core.config").plugins
    local plugin = plugins[item.basename]
    if plugin then
      item.name = plugin.name
      item.url = plugin.url
      item.lazy = plugin.lazy
    end
  end,
  confirm = "help_or_readme",
})

sources.packages = {
  config = function(opts)
    opts.cwd = LazyVim.root.git()
  end,
  finder = function(opts, ctx)
    return require("snacks.picker.source.proc").proc({
      opts,
      {
        notify = false,
        cmd = "rg",
        -- TODO: add args for opts like hidden, exclude, etc.
        -- See ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/source/grep
        args = {
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--trim",
          "--max-count=1",
          "-g",
          "package.json",
          "-r",
          "'$1'",
          "--",
          '"name": "(.+?)",?',
        },
      },
    }, ctx)
  end,
  format = "file",
  icons = {
    files = {
      enabled = false,
    },
  },
  formatters = {
    file = {
      filename_first = false,
      git_status_hl = false,
    },
  },
  transform = function(item, ctx)
    item.cwd = ctx.picker.opts.cwd
    local file, line, col, text = item.text:match("^(.+):(%d+):(%d+):'(.*)'$")
    if not file then
      if not item.text:match("WARNING") then
        Snacks.notify.error("invalid grep output:\n" .. item.text)
      end
      return false
    else
      item._path = file
      item.file = file
      item.label = text
      item.pos = { tonumber(line), tonumber(col) - 1 }
    end
  end,
}

sources.lines = {
  on_show = disable_main_preview_winbar,
}

sources.symbols = {
  multi = { "treesitter", "lsp_symbols" },
  -- TODO: custom formatter that gives more context to common patterns.
  -- anonymous function expressions (in lua, in JS)
  -- const function expressions (in JS)
  format = "lsp_symbol",
  tree = true,
  -- sort = { fields = { "line" } },
  -- matcher = {
  --   sort_empty = true,
  -- },
  filter = {
    default = {
      "Class",
      "Constructor",
      "Constant",
      "Enum",
      "Field",
      "Function",
      "Interface",
      "Method",
      "Module",
      "Namespace",
      "Package",
      "Property",
      "Struct",
      "Trait",
      "Variable",
    },
  },
  layout = {
    preview = "main",
    layout = {
      row = 0.2,
      width = 0.3,
      min_width = 50,
    },
  },
  on_show = function(picker)
    disable_main_preview_winbar(picker)
    resize_list_to_fit_vertical(picker)
  end,
  transform = function(item, ctx)
    if item.source_id == 1 and item.text == "root" then
      return false
      -- ctx.meta.root = ctx.meta.root or item
      -- elseif item.source_id == 2 and item.text == "" then
      --   ctx.meta.root = ctx.meta.root or item
    end

    if ctx.meta.root then
      vim.print(vim.inspect(ctx.meta.root))
      return false
    end

    --   ctx.meta.done = ctx.meta.done or {} ---@type table<number, table<string, table<string, boolean>>>
    --   local kind, name, line = item.kind, item.name, item.pos[1]
    --
    --   if not kind or not name or not line then
    --     return false
    --   end
    --
    --   item.line = line
    --
    --   kind = kind:lower()
    --
    --   local kinds = ctx.meta.done[line]
    --
    --   if not kinds or not kinds[kind] then
    --     kinds = {}
    --     kinds[kind] = {}
    --     kinds[kind][name] = item
    --     ctx.meta.done[line] = kinds
    --   else
    --     local names = kinds[kind]
    --     for n in pairs(names) do
    --       -- if names end the same, assume its the same symbol.
    --       if name:find(n .. "$") or n:find(name .. "$") then
    --         local original_item = names[n]
    --         -- prefer details of non-ts items over ts items.
    --         if item.ts_kind == nil then
    --           for k, v in pairs(item) do
    --             original_item[k] = v
    --           end
    --         end
    --         return false
    --       end
    --     end
    --   end
  end,
}

-- TODO: source that acts like symbols source but for jumps.
-- could bind on C-o/C-i and C-n/C-p to work like bufjump.
-- source.bufjump

return sources
