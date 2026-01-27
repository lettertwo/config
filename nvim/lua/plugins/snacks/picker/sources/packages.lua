---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local packages_sources = {}

packages_sources.packages = {
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

return packages_sources
