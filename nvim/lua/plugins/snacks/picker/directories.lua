---@module "snacks"

---@type snacks.picker.finder
local function find_directories(opts, ctx)
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
    "--follow",
    "--max-depth",
    max_depth,
    ".",
    cwd,
  }

  return require("snacks.picker.source.proc").proc(
    vim.tbl_deep_extend("force", opts, {
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
    }),
    ctx
  )
end

return {
  "folke/snacks.nvim",
  --stylua: ignore
  keys = {
    -- directory sources
    { "<leader>fn", LazyVim.pick("node_modules"), desc = "Find Package (node_modules)" },
    { "<leader>fP", LazyVim.pick("plugins"),      desc = "Find Plugin (lazy)" },
    { "<leader>fp", LazyVim.pick("packages"),     desc = "Find Package" },
  },
  ---@type snacks.Config
  opts = {
    picker = {
      sources = {
        directories = {
          finder = find_directories,
          preview = "directory",
        },

        node_modules = {
          finder = find_directories,
          preview = "directory",
          config = function(opts)
            local package_dir = LazyVim.root.detectors.pattern(0, "package.json")[1]
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
          finder = find_directories,
          preview = "directory",
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
        },
      },
    },
  },
}
