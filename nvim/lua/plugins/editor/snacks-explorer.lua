local _, recall_util = pcall(require, "plugins.editor.recall.util")

---@module "snacks"

---@param item snacks.picker.Item
---@param picker snacks.Picker
local function format_marked_file(item, picker)
  local ret = require("snacks.picker.format").file(item, picker)
  if item.marked then
    table.insert(ret, {
      col = 0,
      virt_text = { { LazyVim.config.icons.tag, "@tag" } },
      virt_text_pos = "right_align",
      hl_mode = "combine",
    })
  end
  return ret
end

---@param opts snacks.picker.explorer.Config
---@param ctx snacks.picker.finder.ctx
local function marked_explorer(opts, ctx)
  -- Cache marks in context to avoid repeated lookups
  ---@cast ctx +{ marked_files: string[]? }
  if recall_util and not ctx.marked_files then
    ctx.marked_files = recall_util.iter_marked_files():totable()
  end
  return require("snacks.picker.source.explorer").explorer(opts, ctx)
end

---@param item snacks.picker.Item
---@param ctx snacks.picker.finder.ctx
local function transform_marked_item(item, ctx)
  ---@cast ctx +{ marked_files: string[]? }
  if not ctx.marked_files or #ctx.marked_files < 1 then
    return item
  end

  -- Try multiple ways to get the file path
  local filepath = item.file or item.path
  if not filepath and Snacks.picker.util and Snacks.picker.util.path then
    filepath = Snacks.picker.util.path(item)
  end

  if filepath then
    local normalized = vim.fs.normalize(filepath)
    if vim.list_contains(ctx.marked_files, normalized) then
      item.marked = true
    end
  end

  return item
end

-- An action to toggle recall (global) mark on a file.
---@param picker snacks.Picker
---@param item snacks.picker.Item
local function toggle_mark(picker, item)
  if recall_util then
    local filepath = item.file or item.path
    if not filepath and Snacks.picker.util and Snacks.picker.util.path then
      filepath = Snacks.picker.util.path(item)
    end
    if filepath then
      recall_util.toggle(filepath)
      require("snacks.explorer.actions").actions.explorer_update(picker)
    end
  else
    vim.notify("recall utility not found", vim.log.levels.WARN)
  end
end

return {
  {
    "folke/snacks.nvim",
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      explorer = {
        replace_netrw = false,
      },
      sources = {
        explorer = {
          finder = marked_explorer,
          format = format_marked_file,
          transform = transform_marked_item,
          actions = { toggle_mark = toggle_mark },
          win = {
            list = {
              keys = {
                ["<C-m>"] = "toggle_mark",
                ["<C-i>"] = "toggle_ignored",
                ["<C-h>"] = "toggle_hidden",
              },
            },
          },
        },
      },
    },
    keys = {
      { "<leader>e", false },
      {
        "<leader>fe",
        function()
          Snacks.explorer({ cwd = LazyVim.root(), layout = { layout = { width = 0.3 } } })
        end,
        desc = "File Tree (root dir)",
      },
      {
        "<leader>fE",
        function()
          Snacks.explorer({ layout = { layout = { width = 0.3 } } })
        end,
        desc = "File Tree (cwd)",
      },
      { "<leader>E", "<leader>fE", desc = "File Tree (cwd)", remap = true },
    },
  },
}
