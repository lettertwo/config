---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local directories_sources = {}

directories_sources.directories = {
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
directories_sources.node_modules = vim.tbl_extend("force", directories_sources.directories, {
  config = function(opts)
    local package_dir = LazyVim.root.detectors.pattern(0, "package.json")[1]
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

directories_sources.plugins = vim.tbl_extend("force", directories_sources.directories, {
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

return directories_sources
