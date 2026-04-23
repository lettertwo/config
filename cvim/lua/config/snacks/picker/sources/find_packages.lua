---@module "snacks"

---@type snacks.picker.finder
local function find_packages(opts, ctx)
  local cwd = ctx.picker.opts.cwd or opts.cwd or Config.root("git") or vim.fn.getcwd()

  if vim.fn.isdirectory(cwd) ~= 1 then
    return {}
  end

  local cmd = "rg"
  -- TODO: add args for opts like hidden, exclude, etc.
  -- See ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/source/files
  local args = {
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--trim",
    "--follow",
    "--max-count=1",
    "-g",
    "package.json",
    "-r",
    "'$1'",
    "--",
    '"name": "(.+?)",?',
  }

  return require("snacks.picker.source.proc").proc(
    vim.tbl_deep_extend("force", opts, {
      notify = false,
      cmd = cmd,
      args = args,
      transform = function(item)
        if not item.text then
          Snacks.notify.error("empty grep output")
          return false
        end
        local file, line, col, text = item.text:match("^(.+):(%d+):(%d+):'(.*)'$")
        if not file then
          if not item.text:match("WARNING") then
            Snacks.notify.error("invalid grep output:\n" .. item.text)
          end
          return false
        end
        item.cwd = ctx.picker.opts.cwd
        item._path = file
        item.dirname = vim.fs.dirname(file)
        item.basename = vim.fs.basename(item.dirname)
        item.file = file
        item.label = text
        item.pos = { tonumber(line), tonumber(col) - 1 }
      end,
    }),
    ctx
  )
end

return find_packages
