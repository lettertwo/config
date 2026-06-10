---@module "snacks"

---@type snacks.picker.finder
local function find_directories(opts, ctx)
  local cwd = ctx.picker.opts.cwd or opts.cwd or vim.fn.getcwd()
  ---@diagnostic disable-next-line: undefined-field
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

return find_directories
