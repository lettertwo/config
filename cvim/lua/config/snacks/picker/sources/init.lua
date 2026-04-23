---@module "snacks"

local find_directories = require("config.snacks.picker.sources.find_directories")
local find_packages = require("config.snacks.picker.sources.find_packages")
local find_symbols = require("config.snacks.picker.sources.find_symbols")
local scope = require("config.snacks.picker.sources.scope")
local title_path = require("config.snacks.picker.sources.title_path")

---@param picker snacks.Picker
local function select_current_buffer(picker)
  for i, item in ipairs(picker.list.items) do
    if item and item.flags and item.flags:find("%%") then
      picker.list:set_target(i)
      break
    end
  end
end

return {
  explorer = require("config.snacks.picker.sources.explorer"),
  buffers = { config = scope("buffers") },
  files = { config = scope("files"), format = title_path },
  recent = { config = scope("recent"), format = title_path },
  grep = { config = scope("grep"), format = title_path },
  packages = { finder = find_packages, confirm = "mini_files" },
  directories  = {
    finder = find_directories,
    preview = "directory",
    format = title_path,
    confirm = "mini_files",
  },
  node_modules = {
    finder = find_directories,
    preview = "directory",
    format = title_path,
    confirm = "mini_files",
    config = function(opts)
      local package_dir = vim.fs.root(0, { "package.json" })
      local cwd = package_dir or vim.fn.getcwd()
      opts.cwd = vim.fs.joinpath(cwd, "node_modules")
      opts.max_depth = 2
    end,
    transform = function(item)
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
    end,
  },
  plugins = {
    finder = function(opts, ctx)
      local plugins = vim.pack.get()
      for _, plugin in ipairs(plugins) do
        plugin.file = plugin.path
        plugin.name = plugin.spec.name
        plugin.url = plugin.spec.src
      end
      return plugins
    end,
    preview = "directory",
    format = title_path,
    confirm = "help_or_readme",
  },
  switch = {
    config = scope("switch"),
    multi = { "buffers", "recent", "files" },
    matcher = {
      cwd_bonus = true, -- boost cwd matches
      frecency = true, -- use frecency boosting
      sort_empty = false, -- sort even when the filter is empty
    },
    format = title_path,
    transform = "unique_file",
    on_show = select_current_buffer,
  },
  symbols = {
    finder = find_symbols,
    layout = "jump",
    on_show = function(picker)
      disable_main_preview_winbar(picker)
      resize_list_to_fit_vertical(picker)
    end,
    matcher = {
      sort_empty = true,
      keep_parents = true,
      on_match = function(_, item)
        local parent = item.parent
        -- HACK: make sure the top-level parent is marked as root.
        -- There are cases (maybe with treesitter?) where the root node is not marked.
        while parent and not parent.root do
          if parent.text == "root" and not parent.parent then
            parent.root = true
            break
          end
          parent = parent.parent
        end
      end,
    },
    sort = { fields = { "sort_key" } },
    format = "lsp_symbol",
  },
  jumps = {
    layout = "jump",
    on_show = function(picker)
      disable_main_preview_winbar(picker)
      resize_list_to_fit_vertical(picker)
    end,
  },
  lines = {
    layout = "jump",
    on_show = function(picker)
      disable_main_preview_winbar(picker)
      resize_list_to_fit_vertical(picker)
    end,
  },
}
