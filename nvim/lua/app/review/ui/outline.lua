-- Outline sidebar: a snacks picker listing the docket's files grouped under
-- one header per changeset, with an independent tree toggle (path trie
-- instead of a bare list). Ported from the POC's
-- ui/outline_snacks.lua; staging/comments/layout actions arrive with their
-- owning milestones (M4/M5/stretch).
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

-- Exposed so ui/peek.lua's dir listing can reuse the same worktree-column
-- glyph/highlight mapping instead of re-deriving it.
M.Y_STATUS = Y_STATUS

local function setup_hl()
  vim.api.nvim_set_hl(0, "ReviewOutlineTitle", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "ReviewOutlineCounter", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "ReviewOutlineDir", { link = "Comment", default = true })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("ReviewOutlineHl", { clear = true }),
  callback = setup_hl,
})

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
-- guides. `prefix` accumulates the dir path independently of `parent_item`
-- (which may be a changeset header, not a dir) — needed by peek/toggle-tree/
-- <CR> to resolve a dir item back to a real repo-relative path. Pure;
-- exposed for unit tests.
---@param node table
---@param parent_item table?
---@param items table[]
---@param prefix string?
function M._emit_tree_node(node, parent_item, items, prefix)
  prefix = prefix or ""
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
      local path = prefix == "" and key or (prefix .. "/" .. key)
      local dir_item = {
        type = "dir",
        dir = true,
        open = true,
        parent = parent_item,
        last = is_last,
        text = key,
        _name = key,
        path = path,
        has_changes = node_has_changes(child),
        idx = #items + 1,
      }
      table.insert(items, dir_item)
      M._emit_tree_node(child, dir_item, items, path)
    end
  end
end

---@class Review.OutlineView
---@field tree boolean
---@field docket Review.Docket
---@field on_select fun(item: table)
---@field on_close fun()
---@field _picker snacks.Picker?
---@field _suppress_sync boolean  true while on_change's own docket:focus_file() call is in flight
local OutlineView = {}
OutlineView.__index = OutlineView

---@param opts {docket: Review.Docket, on_select: fun(item: table), on_close: fun()}
---@return Review.OutlineView
function M.new(opts)
  local self = setmetatable({}, OutlineView)
  self.docket = opts.docket
  self.on_select = opts.on_select
  self.on_close = opts.on_close
  self.tree = opts.docket.state.outline_tree or false
  self._picker = nil
  self._suppress_sync = false

  self:open()
  return self
end

-- Build the picker item list for a docket: a header per changeset, then its
-- files. Needs only docket.files/.changesets; exposed for unit tests.
---@param docket {files: Review.FileChange[], changesets: Review.Changeset[]}
---@param tree boolean?  nest files under path-trie dir rows instead of a bare list
---@param order "head-first"|"base-first"|nil display order for headers (default base-first)
---@return table[]
function M._items_for(docket, tree, order)
  local items = {}

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
      _cs_idx = reversed and (n - ci + 1) or ci,
      _cs_total = n,
      idx = #items + 1,
    }
    table.insert(items, header)
    if tree then
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

  if #items == 0 then
    table.insert(items, { type = "empty", text = "(no changes)", idx = 1 })
  end

  return items
end

function OutlineView:_build_items()
  return M._items_for(self.docket, self.tree, self.docket.state.stack_order)
end

-- Locate the outline row for a docket's current file. Items keep one entry
-- per changeset occurrence, so identity match is exact. Pure; exposed for
-- unit tests.
---@param items table[]
---@param file Review.FileChange?
---@return integer?
function M._find_row(items, file)
  if not file then
    return nil
  end
  for i, item in ipairs(items) do
    if item.change == file then
      return i
    end
  end
  return nil
end

-- Render a single outline row's highlighted chunks. `can_stage` comes from
-- docket.source:can_stage() (whether XY git-short columns apply) and is
-- threaded in rather than read off the docket, so this stays callable
-- without a live picker/docket. Exposed for unit tests.
---@param item table
---@param picker snacks.Picker
---@param can_stage boolean
---@return snacks.picker.Highlight[]
function M._format_item(item, picker, can_stage)
  local ret = require("snacks.picker.format").tree(item, picker)

  if item.type == "changeset" then
    local cs = item.changeset
    -- Mark the docket's current position in the stack.
    if cs.current then
      ret[#ret + 1] = { "● ", "DiagnosticOk" }
    end
    -- A Pending or Failed changeset has no files, so this header mark and
    -- the peek it opens are the only place its state shows.
    if cs.status == "pending" then
      ret[#ret + 1] = { "○ ", "Comment" }
    elseif cs.status == "failed" then
      ret[#ret + 1] = { "✗ ", "ErrorMsg" }
    end
    ret[#ret + 1] = { "\u{f418} ", "ReviewOutlineCounter" }
    ret[#ret + 1] = { string.format("[%d/%d] ", item._cs_idx, item._cs_total), "ReviewOutlineCounter" }
    -- cs.branch is only set on commit-unit specs (source/stack.lua); a
    -- branch header has no sha of its own to show.
    if cs.branch then
      local sha = (cs.head_sha or cs.id or ""):sub(1, 8)
      ret[#ret + 1] = { sha .. " ", "ReviewOutlineCounter" }
    end
    ret[#ret + 1] = { cs.title, "ReviewOutlineTitle" }
    if cs.branch then
      ret[#ret + 1] = { "  " .. cs.branch, "ReviewOutlineCounter" }
    end
    if cs.pr_number then
      ret[#ret + 1] = { "  #" .. cs.pr_number, "ReviewOutlineCounter" }
    end
    if cs.status == "failed" and cs.error then
      ret[#ret + 1] = { "  " .. cs.error, "ErrorMsg" }
    end
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
    -- Rows directly under a changeset header have no directory row above
    -- them (tree file items are parented to one, which already carries the
    -- path), so truncation would otherwise eat the dirname before whatever
    -- part of it is being scanned for.
    local nested_in_tree = item.parent and item.parent.type == "dir"
    if not nested_in_tree then
      local dirname = vim.fn.fnamemodify(file.path, ":h")
      if dirname ~= "." then
        ret[#ret + 1] = { "  " .. dirname, "ReviewOutlineDir" }
      end
    end
  elseif item.type == "empty" then
    ret[#ret + 1] = { item.text, "Comment" }
  end

  return ret
end

-- (Re)open the picker sidebar. No-op when already open.
function OutlineView:open()
  if self:is_open() then
    self._picker:focus("list")
    return
  end

  setup_hl()

  local view = self
  local docket = self.docket
  local can_stage = docket.source:can_stage()

  local registry = require("app.review.actions")
  local review_config = require("app.review.config")
  local ctx = { docket = docket, view = view, close = self.on_close }

  -- Every registry action with an outline handler, wrapped for snacks: the
  -- picker under the cursor is read fresh on each press (`ctx.picker`), not
  -- captured once at open, since it drives which row (file, dir, changeset)
  -- an op like stage/discard applies to.
  local actions = {}
  for name, action in pairs(registry.list) do
    if action.outline then
      actions["review_" .. name] = {
        desc = action.desc,
        action = function(picker)
          ctx.picker = picker
          action.outline.handler(ctx)
        end,
      }
    end
  end

  -- Filter/list-focus mechanics: not part of the action registry since a
  -- config key table would never rebind them — they're how the input line
  -- and the list hand focus back and forth, not a review operation.
  actions.review_focus_list = {
    desc = "Focus list",
    action = function(picker)
      picker:focus("list")
    end,
  }
  actions.review_input_normal = {
    desc = "Normal mode",
    action = function()
      vim.cmd("stopinsert")
    end,
  }
  actions.review_clear_and_focus_list = {
    desc = "Clear filter",
    action = function(picker)
      picker.input:set("", "")
      picker:find({ refresh = false })
      picker:focus("list")
    end,
  }

  -- Bare-string list.keys values become their own desc verbatim
  -- (snacks/win.lua: `spec = { key, spec, desc = spec }`) rather than
  -- looking up the action's desc, so every key here gets desc supplied
  -- explicitly instead.
  local list_keys = {}
  for lhs, name in pairs(review_config.keys.outline) do
    local action_name = "review_" .. name
    list_keys[lhs] = { lhs, action_name, desc = actions[action_name].desc }
  end
  -- <Esc> always runs the peek → close cascade; config can't rebind it.
  list_keys["<Esc>"] = { "<Esc>", "review_close", desc = actions.review_close.desc }

  local function format_item(item, picker)
    return M._format_item(item, picker, can_stage)
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
        view._suppress_sync = true
        local ok, err = pcall(docket.focus_file, docket, item.change)
        view._suppress_sync = false
        if not ok then
          error(err, 0)
        end
      end
    end,
    actions = actions,
    win = {
      input = {
        keys = {
          ["<Esc>"] = { "review_input_normal", mode = "i", desc = actions.review_input_normal.desc },
          ["<CR>"] = { "review_focus_list", mode = { "i", "n" }, desc = actions.review_focus_list.desc },
          ["<C-c>"] = {
            "review_clear_and_focus_list",
            mode = { "i", "n" },
            desc = actions.review_clear_and_focus_list.desc,
          },
        },
      },
      list = {
        keys = vim.tbl_extend("force", list_keys, {
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
        }),
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

-- Reposition the picker cursor to the row matching the docket's current
-- file, without stealing focus or rebuilding the item list. No-op while
-- on_change's own docket:focus_file() call is in flight (see _suppress_sync
-- below — that direction is already authoritative, so re-viewing the row
-- here would just be a redundant echo) or when the current file isn't among
-- the displayed items — e.g. filtered out by an active search; the filter
-- is never cleared to force a match. Explicit nav keymaps invoked while the
-- outline is focused (e.g. ]f from the outline) are NOT on_change-driven, so
-- they fall through and do reposition the cursor.
---@param file Review.FileChange?
function OutlineView:sync_to_current(file)
  if not self:is_open() or self._suppress_sync then
    return
  end
  local row = M._find_row(self._picker:items(), file)
  if row then
    self._picker.list:view(row)
  end
end

function OutlineView:toggle_tree()
  self.tree = not self.tree
  self.docket.state.outline_tree = self.tree
  self:render()
  self:sync_to_current(self.docket:current_file())
  vim.notify("Outline tree: " .. (self.tree and "on" or "off"), vim.log.levels.INFO, { title = "Review" })
end

function OutlineView:toggle_stack_order()
  local order = self.docket.state.stack_order == "head-first" and "base-first" or "head-first"
  self.docket.state.stack_order = order
  self:render()
  self:sync_to_current(self.docket:current_file())
  vim.notify("Stack order: " .. order, vim.log.levels.INFO, { title = "Review" })
end

function OutlineView:destroy()
  if self:is_open() then
    self._picker:close()
  end
  self._picker = nil
end

return M
