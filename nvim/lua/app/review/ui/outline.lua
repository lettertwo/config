-- Outline sidebar: a snacks picker listing the docket's files, with four
-- modes — flat, tree (path trie), stack (grouped by changeset), stack-tree.
-- Ported from the POC's ui/outline_snacks.lua; staging/comments/layout
-- actions arrive with their owning milestones (M4/M5/stretch).
--
-- Refresh gotcha (POC-proven): render() must use picker:refresh(), which
-- preserves cursor and filter across the item rebuild; picker:find() reseeds
-- the list and belongs only in the clear-input action.

---@module "snacks"

local M = {}

-- XY git-short format: X = staged/index column, Y = worktree/unstaged column
local X_STATUS = {
  M = { "M", "WarningMsg" },
  A = { "A", "String" },
  D = { "D", "ErrorMsg" },
  R = { "R", "WarningMsg" },
  C = { "C", "WarningMsg" },
  B = { "B", "Comment" },
  U = { "?", "Comment" },
}
local Y_STATUS = {
  M = { "M", "DiffChange" },
  A = { "A", "DiffAdd" },
  D = { "D", "DiffDelete" },
  R = { "R", "DiffChange" },
  C = { "C", "DiffChange" },
  B = { "B", "Comment" },
  U = { "?", "Comment" },
}

local function filetype_icon(path)
  local ok, icon, hl = pcall(Snacks.util.icon, path, "file")
  if ok and icon and icon ~= "" then
    return icon .. " ", hl
  end
  return "", nil
end

local function node_has_changes(node)
  if node.__file then
    return true
  end
  for k, child in pairs(node) do
    if k ~= "__path" and k ~= "__file" and node_has_changes(child) then
      return true
    end
  end
  return false
end

-- Build a path trie from file paths. `changed` maps path → FileChange;
-- `__path`/`__file` are reserved leaf keys. Pure; exposed for unit tests.
---@param paths string[]
---@param changed table<string, Review.FileChange>
---@return table
function M._build_path_tree(paths, changed)
  local tree = {}
  for _, path in ipairs(paths) do
    local parts = vim.split(path, "/", { plain = true })
    local node = tree
    for i, part in ipairs(parts) do
      if i == #parts then
        node[part] = { __path = path, __file = changed[path] }
      else
        node[part] = node[part] or {}
        node = node[part]
      end
    end
  end
  return tree
end

-- Emit picker items recursively from a path trie node: directories after
-- files at each level, alpha within each group, `last` flags for tree
-- guides. Pure; exposed for unit tests.
---@param node table
---@param parent_item table?
---@param items table[]
function M._emit_tree_node(node, parent_item, items)
  local real_keys = {}
  for k in pairs(node) do
    if k ~= "__path" and k ~= "__file" then
      table.insert(real_keys, k)
    end
  end
  table.sort(real_keys, function(a, b)
    local a_is_file = node[a].__path ~= nil
    local b_is_file = node[b].__path ~= nil
    if a_is_file ~= b_is_file then
      return not a_is_file
    end
    return a < b
  end)

  for i, key in ipairs(real_keys) do
    local child = node[key]
    local is_last = (i == #real_keys)

    if child.__path then
      table.insert(items, {
        type = "file",
        change = child.__file,
        text = child.__file.path,
        parent = parent_item,
        last = is_last,
        _name = key,
        idx = #items + 1,
      })
    else
      local dir_item = {
        type = "dir",
        dir = true,
        open = true,
        parent = parent_item,
        last = is_last,
        text = key,
        _name = key,
        has_changes = node_has_changes(child),
        idx = #items + 1,
      }
      table.insert(items, dir_item)
      M._emit_tree_node(child, dir_item, items)
    end
  end
end

---@class Review.OutlineView
---@field mode "flat"|"tree"|"stack"|"stack-tree"
---@field docket Review.Docket
---@field on_select fun(item: table)
---@field on_close fun()
---@field _picker snacks.Picker?
local OutlineView = {}
OutlineView.__index = OutlineView

---@param opts {docket: Review.Docket, on_select: fun(item: table), on_close: fun()}
---@return Review.OutlineView
function M.new(opts)
  local self = setmetatable({}, OutlineView)
  self.docket = opts.docket
  self.on_select = opts.on_select
  self.on_close = opts.on_close
  self.mode = opts.docket.state.outline_mode or "flat"
  self._picker = nil

  self:open()
  return self
end

-- Build the picker item list for a docket in a given mode. Needs only
-- docket.files/.changesets; exposed for unit tests.
---@param docket {files: Review.FileChange[], changesets: Review.Changeset[]}
---@param mode "flat"|"tree"|"stack"|"stack-tree"
---@param order "head-first"|"base-first"|nil display order for stack/stack-tree headers (default base-first)
---@return table[]
function M._items_for(docket, mode, order)
  local items = {}

  if mode == "flat" then
    -- A stack can touch the same path in several changesets; flat shows each
    -- path once, bound to its newest occurrence (the tree modes' path tries
    -- already collapse duplicates the same way — last write wins).
    local by_path = {}
    for _, file in ipairs(docket.files) do
      local item = by_path[file.path]
      if item then
        item.change = file
      else
        item = {
          type = "file",
          change = file,
          text = file.path,
          idx = #items + 1,
        }
        by_path[file.path] = item
        table.insert(items, item)
      end
    end
  elseif mode == "tree" then
    local changed = {}
    for _, f in ipairs(docket.files) do
      changed[f.path] = f
    end
    local paths = vim.tbl_map(function(f)
      return f.path
    end, docket.files)
    M._emit_tree_node(M._build_path_tree(paths, changed), nil, items)
  elseif mode == "stack" or mode == "stack-tree" then
    local n = #docket.changesets
    -- docket.changesets is always base->head; head-first only flips display order.
    local reversed = order == "head-first"
    for ci = 1, n do
      local cs = docket.changesets[reversed and (n - ci + 1) or ci]
      local header = {
        type = "changeset",
        changeset = cs,
        dir = true,
        open = true,
        last = (ci == n),
        text = cs.title,
        _cs_idx = ci,
        _cs_total = n,
        idx = #items + 1,
      }
      table.insert(items, header)
      if mode == "stack-tree" then
        local changed = {}
        for _, f in ipairs(cs.files) do
          changed[f.path] = f
        end
        local paths = vim.tbl_map(function(f)
          return f.path
        end, cs.files)
        table.sort(paths)
        M._emit_tree_node(M._build_path_tree(paths, changed), header, items)
      else
        local nf = #cs.files
        for fi, file in ipairs(cs.files) do
          table.insert(items, {
            type = "file",
            change = file,
            parent = header,
            last = (fi == nf),
            text = file.path,
            idx = #items + 1,
          })
        end
      end
    end
  end

  if #items == 0 then
    table.insert(items, { type = "empty", text = "(no changes)", idx = 1 })
  end

  return items
end

function OutlineView:_build_items()
  return M._items_for(self.docket, self.mode, self.docket.state.stack_order)
end

-- (Re)open the picker sidebar. No-op when already open.
function OutlineView:open()
  if self:is_open() then
    self._picker:focus("list")
    return
  end

  local view = self
  local docket = self.docket
  local can_stage = docket.source:can_stage()

  ---@param item table
  ---@param picker snacks.Picker
  ---@return snacks.picker.Highlight[]
  local function format_item(item, picker)
    local ret = require("snacks.picker.format").tree(item, picker)

    if item.type == "changeset" then
      local cs = item.changeset
      local label = string.format("[%d/%d] %s", item._cs_idx, item._cs_total, cs.title)
      if cs.pr_number then
        label = label .. "  #" .. cs.pr_number
      end
      -- Mark the docket's current position in the stack.
      if cs.current then
        ret[#ret + 1] = { "● ", "DiagnosticOk" }
      end
      ret[#ret + 1] = { label, "SnacksPickerDir" }
    elseif item.type == "dir" then
      local ok, icon, hl = pcall(Snacks.util.icon, item._name, "directory")
      local diricon = (ok and icon and icon ~= "") and (icon .. " ") or " "
      local dirhl = (ok and hl) or "SnacksPickerDir"
      ret[#ret + 1] = { diricon, dirhl }
      ret[#ret + 1] = { item._name .. "/", item.has_changes and nil or "SnacksPickerDir" }
    elseif item.type == "file" then
      local file = item.change
      local x = X_STATUS[file.status] or { "?", "Comment" }
      local y = Y_STATUS[file.status] or { "?", "Comment" }
      local fticon, fthl = filetype_icon(file.path)
      local name = file.old_path
          and (vim.fn.fnamemodify(file.old_path, ":t") .. " → " .. vim.fn.fnamemodify(file.path, ":t"))
        or vim.fn.fnamemodify(file.path, ":t")
      if can_stage then
        -- git --short XY format: X=index, Y=worktree, then a space gap
        if file.status == "U" then
          ret[#ret + 1] = { x[1], x[2] }
          ret[#ret + 1] = { y[1] .. " ", y[2] }
        elseif file.staged then
          ret[#ret + 1] = { x[1], x[2] }
          ret[#ret + 1] = { "  " }
        elseif file.staged_hunks and #file.staged_hunks > 0 then
          ret[#ret + 1] = { x[1], x[2] }
          ret[#ret + 1] = { y[1] .. " ", y[2] }
        else
          ret[#ret + 1] = { " " }
          ret[#ret + 1] = { y[1] .. " ", y[2] }
        end
      else
        ret[#ret + 1] = { y[1] .. " ", y[2] }
      end
      ret[#ret + 1] = { fticon, fthl }
      ret[#ret + 1] = { name }
    elseif item.type == "empty" then
      ret[#ret + 1] = { item.text, "Comment" }
    end

    return ret
  end

  self._picker = Snacks.picker.pick({
    title = "Review",
    show_empty = true,
    auto_close = false,
    focus = "list",
    jump = { close = false },
    -- Custom sidebar layout without a preview pane
    layout = {
      layout = {
        backdrop = false,
        width = 35,
        min_width = 35,
        height = 0,
        position = "left",
        border = "none",
        box = "vertical",
        { win = "input", height = 1, border = true, title = "{title} {live}", title_pos = "center" },
        { win = "list", border = "none" },
      },
    },
    finder = function()
      return view:_build_items()
    end,
    format = format_item,
    confirm = function(_, item)
      if item then
        view.on_select(item)
      end
    end,
    on_change = function(picker, item)
      -- Focus-follow only while the user is IN the outline: on_change also
      -- fires from programmatic refreshes (staging ops, save watcher), and
      -- following then would yank the docket to the outline's cursor row.
      if not picker:is_focused() then
        return
      end
      if item and item.change and item.change ~= docket:current_file() then
        docket:focus_file(item.change)
      end
    end,
    actions = {
      review_cycle_mode = {
        desc = "Cycle outline mode",
        action = function()
          view:cycle_mode()
        end,
      },
      review_toggle_stack_order = {
        desc = "Toggle stack order",
        action = function()
          view:toggle_stack_order()
        end,
      },
      review_next_file = {
        desc = "Next file",
        action = function()
          docket:next_file()
        end,
      },
      review_prev_file = {
        desc = "Prev file",
        action = function()
          docket:prev_file()
        end,
      },
      review_refresh = {
        desc = "Refresh source",
        action = function()
          docket:refresh()
        end,
      },
      review_layout = {
        desc = "Toggle side-by-side",
        action = function()
          docket:toggle_layout()
        end,
      },
      review_zoom = {
        desc = "Cycle staging zoom",
        action = function()
          docket:cycle_zoom()
        end,
      },
      review_toggle_stage_file = {
        desc = "Stage/unstage file",
        action = function(picker)
          local item = picker:current()
          if item and item.change then
            docket:toggle_stage_file(item.change)
          end
        end,
      },
      review_discard_file = {
        desc = "Discard file",
        action = function(picker)
          local item = picker:current()
          if item and item.change then
            docket:discard_file(item.change)
          end
        end,
      },
      review_stage_all = {
        desc = "Stage all",
        action = function()
          docket:stage_all()
        end,
      },
      review_unstage_all = {
        desc = "Unstage all",
        action = function()
          docket:unstage_all()
        end,
      },
      review_close = {
        desc = "Close review",
        action = function()
          view.on_close()
        end,
      },
      review_focus_list = {
        desc = "Focus list",
        action = function(picker)
          picker:focus("list")
        end,
      },
      review_input_normal = {
        desc = "Normal mode",
        action = function()
          vim.cmd("stopinsert")
        end,
      },
      review_clear_and_focus_list = {
        desc = "Clear filter",
        action = function(picker)
          picker.input:set("", "")
          picker:find({ refresh = false })
          picker:focus("list")
        end,
      },
    },
    win = {
      input = {
        keys = {
          ["<Esc>"] = { "review_input_normal", mode = "i" },
          ["<CR>"] = { "review_focus_list", mode = { "i", "n" } },
          ["<C-c>"] = { "review_clear_and_focus_list", mode = { "i", "n" } },
        },
      },
      list = {
        keys = {
          ["i"] = "review_cycle_mode",
          ["r"] = "review_toggle_stack_order",
          ["l"] = "review_layout",
          ["z"] = "review_zoom",
          ["<Space>"] = "review_toggle_stage_file",
          ["="] = "review_toggle_stage_file",
          ["a"] = "review_stage_all",
          ["A"] = "review_unstage_all",
          ["d"] = "review_discard_file",
          ["]f"] = "review_next_file",
          ["[f"] = "review_prev_file",
          ["R"] = "review_refresh",
          ["q"] = "review_close",
          ["<Esc>"] = "review_close",
          ["/"] = "toggle_focus",
          -- disable snacks defaults that don't apply in the review outline
          ["<C-V>"] = false, -- edit_vsplit
          ["<C-S>"] = false, -- edit_split
          ["<C-T>"] = false, -- tab
          ["<C-Q>"] = false, -- qflist
          ["<C-G>"] = false, -- toggle_live
          ["<C-A>"] = false, -- select_all
          ["<Tab>"] = false, -- select_and_next
          ["<S-Tab>"] = false, -- select_and_prev
          ["<S-CR>"] = false, -- pick_win / jump
          ["<C-W>H"] = false, -- layout_left
          ["<C-W>J"] = false, -- layout_bottom
          ["<C-W>K"] = false, -- layout_top
          ["<C-W>L"] = false, -- layout_right
          ["<a-p>"] = false, -- toggle_preview
          ["<a-f>"] = false, -- toggle_follow
          ["<a-h>"] = false, -- toggle_hidden
          ["<a-i>"] = false, -- toggle_ignored
          ["<a-r>"] = false, -- toggle_regex
          ["<a-m>"] = false, -- toggle_maximize
          ["<a-w>"] = false, -- cycle_win
          ["<a-d>"] = false, -- inspect
          ["<C-b>"] = false, -- preview_scroll_up
          ["<C-f>"] = false, -- preview_scroll_down
        },
      },
    },
  })
end

function OutlineView:is_open()
  return self._picker ~= nil and not self._picker.closed
end

function OutlineView:render()
  if self:is_open() then
    self._picker:refresh()
  end
end

function OutlineView:cycle_mode()
  local modes = { "flat", "tree", "stack", "stack-tree" }
  for i, m in ipairs(modes) do
    if m == self.mode then
      self.mode = modes[(i % #modes) + 1]
      self.docket.state.outline_mode = self.mode
      break
    end
  end
  self:render()
  vim.notify("Outline: " .. self.mode, vim.log.levels.INFO, { title = "Review" })
end

function OutlineView:toggle_stack_order()
  local order = self.docket.state.stack_order == "head-first" and "base-first" or "head-first"
  self.docket.state.stack_order = order
  self:render()
  vim.notify("Stack order: " .. order, vim.log.levels.INFO, { title = "Review" })
end

function OutlineView:destroy()
  if self:is_open() then
    self._picker:close()
  end
  self._picker = nil
end

return M
