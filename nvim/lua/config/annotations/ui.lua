-- User-facing actions for the annotation core: add/edit/delete/dismiss at a
-- line or visual range, toggle one resolved by hand, list via a picker,
-- jump between annotations in a buffer, send a batch, and clear the ones
-- that got resolved. `config/annotations/init.lua` binds these to keys;
-- nothing here assumes a particular key was pressed.

local Store = require("config.annotations.store")
local Anchor = require("config.annotations.anchor")
local Send = require("config.annotations.send")

local UI = {}

local id_counter = 0

local function new_id()
  id_counter = id_counter + 1
  return string.format("%d-%d", os.time(), id_counter)
end

-- Opens a scratch float for a multi-line annotation body, pre-filled with
-- `initial` when editing, and calls `on_submit(body)` on normal-mode <cr>,
-- or nothing on <esc> / q. Insert-mode <cr> still breaks a line, so bodies
-- can span several. The keys are buffer-local, so nothing here reaches the
-- window or file commands (:w, :q) that would act on the wrong thing.
-- Leaving the float any other way (a click elsewhere, <c-w> motions) cancels
-- it too, so a second `add` never stacks a prompt on top of a live one.
---@param initial string?
---@param on_submit fun(body: string)
local function prompt_body(initial, on_submit)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  if initial then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(initial, "\n", { plain = true }))
  end

  local width = math.min(80, math.floor(vim.o.columns * 0.6))
  local height = 8
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " annotation body: <cr> to submit, <esc> to cancel ",
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local body = vim.trim(table.concat(lines, "\n"))
    close()
    if body ~= "" then
      on_submit(body)
    end
  end

  vim.keymap.set("n", "<cr>", submit, { buffer = buf, desc = "Submit annotation" })
  vim.keymap.set("n", "<esc>", close, { buffer = buf, desc = "Cancel annotation" })
  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Cancel annotation" })
  Config.on("WinLeave", buf, close, "Cancel the annotation prompt on focus loss")
end

-- Adds an annotation at the cursor line, or over the given visual range.
---@param opts? { line1: integer, line2: integer }
function UI.add(opts)
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local file = Store.relative_path(name)
  if not file then
    vim.notify("Buffer is not inside a git worktree", vim.log.levels.ERROR, { title = "Annotations" })
    return
  end

  local line1, line2
  if opts then
    line1, line2 = opts.line1, opts.line2
  else
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    line1, line2 = lnum, lnum
  end
  local anchor_text = table.concat(vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false), "\n")

  prompt_body(nil, function(body)
    Store.add({
      id = new_id(),
      file = file,
      lnum = line1,
      end_lnum = line2,
      anchor_text = anchor_text,
      body = body,
      created_at = os.time(),
    })
  end)
end

-- Every annotation whose range covers the cursor line, most recently
-- created first.
---@return Config.Annotations.Record[]
local function annotations_at_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local file = Store.relative_path(name)
  if not file then
    return {}
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local matches = {}
  for _, rec in ipairs(Store.for_file(file)) do
    if lnum >= rec.lnum and lnum <= (rec.end_lnum or rec.lnum) then
      table.insert(matches, rec)
    end
  end
  table.sort(matches, function(a, b)
    return a.created_at > b.created_at
  end)
  return matches
end

-- Resolves to one record among those covering the cursor line: the only one
-- if there's exactly one, otherwise a `vim.ui.select` keyed on each body's
-- first line. Calls `on_pick(rec)`, or nothing if there's no match or the
-- picker is cancelled.
---@param on_pick fun(rec: Config.Annotations.Record)
local function pick_annotation_at_cursor(on_pick)
  local matches = annotations_at_cursor()
  if #matches == 0 then
    vim.notify("No annotation on this line", vim.log.levels.WARN, { title = "Annotations" })
    return
  end
  if #matches == 1 then
    on_pick(matches[1])
    return
  end
  vim.ui.select(matches, {
    prompt = "Multiple annotations on this line, pick one:",
    format_item = function(rec)
      return (vim.split(rec.body, "\n", { plain = true })[1])
    end,
  }, function(choice)
    if choice then
      on_pick(choice)
    end
  end)
end

function UI.edit()
  pick_annotation_at_cursor(function(rec)
    prompt_body(rec.body, function(body)
      Store.update(rec.id, { body = body })
    end)
  end)
end

function UI.delete()
  pick_annotation_at_cursor(function(rec)
    Store.remove(rec.id)
  end)
end

-- Drops the annotation at cursor and, if Claude has resolved it, its rows
-- from resolutions.jsonl too.
function UI.dismiss()
  pick_annotation_at_cursor(function(rec)
    Store.dismiss(rec.id)
  end)
end

-- Toggles resolution on the annotation at cursor. A pending one is marked
-- resolved by hand, for one that never needed to go to Claude at all: prompts
-- for an optional one-line note; leave it blank and just press enter to
-- resolve without one. A resolved one (manual or Claude's) is made pending
-- again.
function UI.resolve()
  pick_annotation_at_cursor(function(rec)
    if rec.resolution then
      Store.unresolve(rec.id)
      return
    end
    vim.ui.input({ prompt = "Resolution note (optional): " }, function(note)
      if note == nil then
        return -- cancelled, e.g. <Esc>
      end
      Store.resolve(rec.id, note)
    end)
  end)
end

function UI.toggle_body()
  Anchor.toggle_body()
end

function UI.toggle_background()
  Anchor.toggle_background()
end

-- Jumps to the next (`dir = 1`) or previous (`dir = -1`) annotation in the
-- current buffer, wrapping.
---@param dir 1|-1
local function jump(dir)
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local file = Store.relative_path(name)
  if not file then
    return
  end
  local records = Store.for_file(file)
  if #records == 0 then
    return
  end
  table.sort(records, function(a, b)
    return a.lnum < b.lnum
  end)
  local cur = vim.api.nvim_win_get_cursor(0)[1]

  local target
  if dir == 1 then
    for _, rec in ipairs(records) do
      if rec.lnum > cur then
        target = rec
        break
      end
    end
    target = target or records[1]
  else
    for i = #records, 1, -1 do
      if records[i].lnum < cur then
        target = records[i]
        break
      end
    end
    target = target or records[#records]
  end
  vim.api.nvim_win_set_cursor(0, { target.lnum, 0 })
end

function UI.next()
  jump(1)
end

function UI.prev()
  jump(-1)
end

-- Lists every annotation in the current worktree via a picker; confirming an
-- item jumps to it, `annotation_delete` removes it, `annotation_resolve`
-- toggles it resolved by hand or back to pending. The preview is the file
-- itself with the selected annotation rendered as the buffer renders it; sent
-- and resolved items are dimmed in the list, and resolved ones carry a state
-- glyph prefix (a checkmark for "changed" and manual resolutions, a dash for
-- "unchanged").
function UI.list()
  local toplevel = Store.toplevel(vim.uv.cwd())

  -- A finder rather than a static `items` list, so `picker:find()` after an
  -- action re-reads the store and the list reflects the change.
  local function finder()
    local items = {}
    for _, rec in ipairs(Store.load()) do
      local prefix = ""
      if rec.resolution then
        local glyph = Anchor.record_state(rec)
        prefix = glyph .. " "
      end
      table.insert(items, {
        text = string.format("%s%s:%d %s", prefix, rec.file, rec.lnum, rec.body:gsub("\n", " ")),
        file = rec.file,
        -- `file` is repo-relative; snacks resolves it against `cwd` for the
        -- preview, and nvim's cwd is not always the toplevel.
        cwd = toplevel,
        pos = { rec.lnum, 0 },
        annotation_id = rec.id,
        annotation = rec,
      })
    end
    return items
  end

  Snacks.picker.pick({
    title = "Annotations",
    finder = finder,
    format = function(item, picker)
      local ret = require("snacks.picker.format").file(item, picker)
      if item.annotation.sent_at then
        for _, chunk in ipairs(ret) do
          chunk[2] = "Comment"
        end
      end
      return ret
    end,
    -- The preview is the real file with the selected annotation drawn on it
    -- by anchor.lua, so it looks the same as it does in the buffer, minus
    -- its neighbours.
    preview = function(ctx)
      Snacks.picker.preview.file(ctx)
      Anchor.render_records(ctx.buf, { ctx.item.annotation })
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        -- item.file is repo-relative; `:edit` resolves relative to nvim's
        -- cwd, which is not always the toplevel (e.g. cwd'd into a subdir).
        local target = toplevel and vim.fs.joinpath(toplevel, item.file) or item.file
        vim.cmd.edit(target)
        vim.api.nvim_win_set_cursor(0, { item.pos[1], 0 })
      end
    end,
    win = {
      preview = { wo = { signcolumn = "yes" } },
      list = {
        keys = { ["x"] = "annotation_delete", ["r"] = "annotation_resolve" },
      },
      -- The input opens in insert mode, where a bare letter belongs to the
      -- filter, so each action also gets a ctrl chord that works in both
      -- modes.
      input = {
        keys = {
          ["x"] = { "annotation_delete", mode = { "n" } },
          ["r"] = { "annotation_resolve", mode = { "n" } },
          ["<c-x>"] = { "annotation_delete", mode = { "i", "n" } },
          ["<c-r>"] = { "annotation_resolve", mode = { "i", "n" } },
        },
      },
    },
    actions = {
      annotation_delete = function(picker, item)
        if item then
          Store.remove(item.annotation_id)
          picker:find()
        end
      end,
      -- Same toggle as UI.resolve, against the picker's current item.
      annotation_resolve = function(picker, item)
        if not item then
          return
        end
        if item.annotation.resolution then
          Store.unresolve(item.annotation_id)
          picker:find()
          return
        end
        vim.ui.input({ prompt = "Resolution note (optional): " }, function(note)
          if note == nil then
            return
          end
          Store.resolve(item.annotation_id, note)
          picker:find()
        end)
      end,
    },
  })
end

function UI.send()
  Send.send()
end

-- Dismisses every resolved annotation, Claude's replies and manual resolves
-- alike: there's nothing left to act on for any of them.
function UI.clear_resolved()
  for _, rec in ipairs(Store.resolved()) do
    Store.dismiss(rec.id)
  end
end

return UI
