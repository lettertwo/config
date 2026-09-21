-- Draws stored annotations as extmarks and writes drifted positions back to
-- the store on save. The JSON in store.lua is the source of truth; every
-- extmark here is rebuilt from it, never the other way around.
--
-- A range annotation is tracked by two extmarks, one at its first line and
-- one at its last (the same extmark serves both roles when the range is a
-- single line). Neovim moves each extmark independently as the buffer is
-- edited, so `sync` reads both back to grow or shrink the stored range;
-- everything in between (the sign column glyph on continuation lines, the
-- background highlight) is redrawn from those two positions on every render
-- and carries no identity of its own.

local Store = require("config.annotations.store")

local Anchor = {}

local ns = vim.api.nvim_create_namespace("config.annotations")
-- Below the extmark default (4096) so overlays that expect to win, like
-- word-diff highlighting, still can.
local SIGN_PRIORITY = 200
local BACKGROUND_PRIORITY = 100

local signs = {
  pending = "▶",
  sent = "▸",
  connector = "│",
  branch = "├",
  range_end = "╵",
  resolved_changed = "✓",
  resolved_unchanged = "–",
}
local show_body = true
local show_background = false

-- Every virt_line chunk in the block (bar, label, body, note, and the
-- trailing pad) needs the same background so the block reads as one solid
-- panel; a plain `link` can't combine one group's background with another's
-- foreground, so the block-only groups below are registered with resolved
-- colors instead. Re-registering on `ColorScheme` keeps them in step with
-- `:colorscheme`, which a plain `link` would have tracked for free.
local BLOCK_HL_GROUPS = {
  { name = "AnnotationBody", fg_from = "Comment" },
  { name = "AnnotationSentBody", fg_from = "Comment" },
  { name = "AnnotationResolution", fg_from = "DiagnosticHint" },
  { name = "AnnotationLabel", fg_from = "Title" },
  -- Combined variants of the three sign groups, for the glyph drawn inside
  -- the block's own gutter segment (see `gutter_segment` below), which needs
  -- the block background behind it like everything else in the block.
  { name = "AnnotationBlockSign", fg_from = "DiagnosticInfo" },
  { name = "AnnotationBlockSentSign", fg_from = "Comment" },
  { name = "AnnotationBlockResolvedSign", fg_from = "DiagnosticHint" },
}

-- Maps a record's plain sign highlight (used in the real sign column) to its
-- block-gutter combined equivalent.
local BLOCK_SIGN_HL = {
  AnnotationSign = "AnnotationBlockSign",
  AnnotationSentSign = "AnnotationBlockSentSign",
  AnnotationResolvedSign = "AnnotationBlockResolvedSign",
}

local function hl_attr(name, attr)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl[attr] or nil
end

local function register_highlights()
  vim.api.nvim_set_hl(0, "AnnotationSign", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "AnnotationRange", { link = "Visual", default = true })
  vim.api.nvim_set_hl(0, "AnnotationSentSign", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "AnnotationResolvedSign", { link = "DiagnosticHint", default = true })
  -- Background for the whole block; linking is fine here since it's the only
  -- attribute this group carries (no foreground text is ever drawn in it
  -- directly, only the padding after the block-only groups' own text).
  vim.api.nvim_set_hl(0, "AnnotationBlock", { link = "CursorLine", default = true })

  -- Not `default = true`: these are computed from the current colorscheme's
  -- colors, not links, so they need to be overwritten on every recompute, not
  -- just defined once.
  -- Read through `AnnotationBlock` (link resolved) so an override of that
  -- one group recolors the whole panel, text rows included.
  local block_bg = hl_attr("AnnotationBlock", "bg")
  for _, spec in ipairs(BLOCK_HL_GROUPS) do
    vim.api.nvim_set_hl(0, spec.name, { fg = hl_attr(spec.fg_from, "fg"), bg = block_bg })
  end
end
register_highlights()
Config.on("ColorScheme", register_highlights, "Recompute annotation block colors for the new colorscheme")

---@type table<integer, table<integer, { id: string, role: "start"|"end" }>> buf -> extmark id -> { record id, role }
local marks_by_buf = {}

-- Ordinary file buffers only: a non-empty `buftype` covers terminals,
-- oil/fugitive-style fake-file buffers, and the annotation body prompt
-- itself, none of which have a real path to resolve.
local function buf_file(buf)
  if vim.bo[buf].buftype ~= "" then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end
  return Store.relative_path(name)
end

local function clamp(lnum, line_count)
  return math.max(1, math.min(lnum, math.max(line_count, 1)))
end

-- Applies configuration from `config/annotations/init.lua`: `signs`, and the
-- `show_body`/`show_background` toggles.
---@param opts { signs?: table, show_body?: boolean, show_background?: boolean }
function Anchor.configure(opts)
  opts = opts or {}
  if opts.signs then
    signs = vim.tbl_extend("force", signs, opts.signs)
  end
  if opts.show_body ~= nil then
    show_body = opts.show_body
  end
  if opts.show_background ~= nil then
    show_background = opts.show_background
  end
end

-- The sign glyph and highlight group for a record's current state: resolved
-- (Claude addressed it, or the user marked it resolved by hand) beats sent
-- (delivered, no reply yet) beats pending (not sent). A manual resolution
-- gets the same checkmark as "changed": either way there's nothing left to
-- act on, which is the distinction this glyph exists to carry.
---@param rec Config.Annotations.Record
---@return string sign_text, string sign_hl
local function record_state(rec)
  if rec.resolution then
    local glyph = rec.resolution.status == "unchanged" and signs.resolved_unchanged or signs.resolved_changed
    return glyph, "AnnotationResolvedSign"
  end
  if rec.sent_at then
    return signs.sent, "AnnotationSentSign"
  end
  return signs.pending, "AnnotationSign"
end

-- The block label's state word: what a reader would call this annotation's
-- current status in one word (or three, for the manual case).
---@param rec Config.Annotations.Record
---@return string
local function state_word(rec)
  if rec.resolution then
    if rec.resolution.status == "manual" then
      return "resolved by you"
    end
    return rec.resolution.status
  end
  if rec.sent_at then
    return "sent"
  end
  return "pending"
end

local BLOCK_WIDTH = 500

-- Appends a trailing `AnnotationBlock`-highlighted pad to `segments` so the
-- background runs the full width of the block regardless of window size:
-- virt_lines truncate at the window edge rather than wrapping, so padding
-- wider than any real window is the only way to guarantee full coverage.
---@param segments string[][]
---@return string[][]
local function block_line(segments)
  local width = 0
  for _, seg in ipairs(segments) do
    width = width + vim.fn.strdisplaywidth(seg[1])
  end
  local pad = BLOCK_WIDTH - width
  if pad > 0 then
    table.insert(segments, { string.rep(" ", pad), "AnnotationBlock" })
  end
  return segments
end

-- The width of the gutter (fold column + sign column + line number) in front
-- of `buf`'s text, from whichever window is showing it: the current window
-- if it is one of them, else the first one found. Nil if no window shows
-- `buf` at all, in which case the caller draws no gutter segment.
---@param buf integer
---@return integer?
local function textoff_for_buf(buf)
  local shown_in = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      table.insert(shown_in, win)
    end
  end
  if #shown_in == 0 then
    return nil
  end
  local current = vim.api.nvim_get_current_win()
  local win = vim.list_contains(shown_in, current) and current or shown_in[1]
  local info = vim.fn.getwininfo(win)[1]
  return info and info.textoff or nil
end

-- The block's own gutter segment: `glyph` at column 0 of a `textoff`-wide
-- chunk, blank-padded the rest of the way, on the block background. This
-- config's statuscolumn (`nvim/lua/app/default/plugins/snacks.lua`, `left =
-- { "sign", "mark" }`) puts the sign column at the leftmost edge of the
-- gutter rather than after a fold column, so column 0 is always right for
-- the glyph here; a statuscolumn with the fold column on the left would need
-- to offset it. Nil (no segment at all) when `textoff` is nil.
---@param glyph string
---@param sign_hl string
---@param textoff integer?
---@return string[]?
local function gutter_segment(glyph, sign_hl, textoff)
  if not textoff or textoff <= 0 then
    return nil
  end
  local block_hl = BLOCK_SIGN_HL[sign_hl] or sign_hl
  local pad = textoff - vim.fn.strdisplaywidth(glyph)
  local text = pad > 0 and (glyph .. string.rep(" ", pad)) or glyph
  return { text, block_hl }
end

-- The full block for one anchor line: a label naming each annotation's
-- state, then its body, then Claude's note if it left one (or the user's, if
-- they resolved it manually with a note). Every line carries the
-- `AnnotationBlock` background and, when a window shows the buffer, a gutter
-- segment that continues the sign column's connector down through the
-- block: `├` (branch) marks where each stacked annotation's own rows begin,
-- `│` (connector) runs down its body/note/separator rows, and the very last
-- row of the whole block closes with `╵` regardless of what it would
-- otherwise have been, so the gutter reads as one continuous line from the
-- anchor sign to the bottom of the panel rather than two disconnected marks.
-- Each annotation's rows use its own state color; the shared closing `╵`
-- uses whichever annotation's row it lands on, which is always the last one
-- in the group.
---@param group Config.Annotations.Record[]
---@param textoff integer? from `textoff_for_buf`
---@return string[][][] virt_lines
local function body_virt_lines(group, textoff)
  local out = {}

  local function row(gutter, text_segments)
    local segments = {}
    if gutter then
      -- A copy, not the same table `gutter` for every row it's passed to:
      -- the closing-glyph step below mutates one specific row's gutter
      -- segment in place, and every row within a record shares the same
      -- `gutter` argument, so without copying that mutation would leak into
      -- every other row built from it.
      table.insert(segments, { gutter[1], gutter[2] })
    end
    vim.list_extend(segments, text_segments)
    return block_line(segments)
  end

  for i, rec in ipairs(group) do
    local _, sign_hl = record_state(rec)
    local branch_gutter = gutter_segment(signs.branch, sign_hl, textoff)
    local connector_gutter = gutter_segment(signs.connector, sign_hl, textoff)

    if i > 1 then
      table.insert(out, row(connector_gutter, {}))
    end

    table.insert(out, row(branch_gutter, { { " annotation · " .. state_word(rec), "AnnotationLabel" } }))

    local body_hl = rec.sent_at and "AnnotationSentBody" or "AnnotationBody"
    for _, body_line in ipairs(vim.split(rec.body, "\n", { plain = true })) do
      table.insert(out, row(connector_gutter, { { "   " .. body_line, body_hl } }))
    end

    local note = rec.resolution and vim.trim(rec.resolution.note or "") or ""
    if note ~= "" then
      local note_lines = vim.split(note, "\n", { plain = true })
      table.insert(out, row(connector_gutter, { { "   ↳ " .. note_lines[1], "AnnotationResolution" } }))
      for j = 2, #note_lines do
        table.insert(out, row(connector_gutter, { { "     " .. note_lines[j], "AnnotationResolution" } }))
      end
    end
  end

  -- Close the gutter: the last row's connector becomes `range_end` in
  -- whatever color it already has (the last annotation's), same width as
  -- what it's replacing so the trailing pad computed by `block_line` above
  -- is still correct.
  if textoff and textoff > 0 and #out > 0 then
    local last_gutter = out[#out][1]
    local pad = textoff - vim.fn.strdisplaywidth(signs.range_end)
    last_gutter[1] = pad > 0 and (signs.range_end .. string.rep(" ", pad)) or signs.range_end
  end

  return out
end

-- Places the sign-column and background extmarks for one record and records
-- the start/end extmark ids so `sync` can read the range back later.
---@param buf integer
---@param rec Config.Annotations.Record
---@param line_count integer
local function place_record(buf, rec, line_count)
  local sign_text, sign_hl = record_state(rec)
  local lnum = clamp(rec.lnum, line_count)
  local end_lnum = clamp(rec.end_lnum or rec.lnum, line_count)
  if end_lnum < lnum then
    end_lnum = lnum
  end
  local multiline = end_lnum > lnum

  local start_id = vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
    sign_text = sign_text,
    sign_hl_group = sign_hl,
    priority = SIGN_PRIORITY,
  })
  local marks = marks_by_buf[buf]
  if marks then
    marks[start_id] = { id = rec.id, role = "start" }
  end

  if multiline then
    -- The range's last line continues the gutter's connector down into the
    -- body block below it when the block is shown; with the block hidden
    -- there's nothing below to continue into, so it closes with `range_end`
    -- instead, same as it always has.
    local end_sign = show_body and signs.connector or signs.range_end
    local end_id = vim.api.nvim_buf_set_extmark(buf, ns, end_lnum - 1, 0, {
      sign_text = end_sign,
      sign_hl_group = sign_hl,
      priority = SIGN_PRIORITY,
    })
    if marks then
      marks[end_id] = { id = rec.id, role = "end" }
    end

    for l = lnum + 1, end_lnum - 1 do
      vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
        sign_text = signs.connector,
        sign_hl_group = sign_hl,
        priority = SIGN_PRIORITY,
      })
    end
  end

  if show_background then
    for l = lnum, end_lnum do
      local line = vim.api.nvim_buf_get_lines(buf, l - 1, l, false)[1] or ""
      vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
        end_col = #line,
        hl_group = "AnnotationRange",
        hl_eol = true,
        priority = BACKGROUND_PRIORITY,
      })
    end
  end
end

-- Clears and redraws every extmark for `buf` from the store.
---@param buf integer
function Anchor.render(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  marks_by_buf[buf] = {}

  local file = buf_file(buf)
  if not file then
    return
  end
  Anchor.render_records(buf, Store.for_file(file))
end

-- Draws `records` into `buf` exactly as `render` would, but for a caller
-- that already knows which records belong there: the picker preview, whose
-- scratch buffer holds a file's contents without carrying its path. Such a
-- buffer must not be tracked in `marks_by_buf`, or `sync` would read its
-- positions back into the store; `render` sets the tracking table up before
-- calling this, and nobody else should.
---@param buf integer
---@param records Config.Annotations.Record[]
function Anchor.render_records(buf, records)
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local line_count = vim.api.nvim_buf_line_count(buf)
  local textoff = textoff_for_buf(buf)

  -- Bodies hang below the last line of their range, so a multi-line
  -- annotation reads top to bottom: code first, then the note about it.
  -- Grouping by that line lets several annotations ending on it share one
  -- body block instead of each drawing its own virt_lines.
  local groups, order = {}, {}
  for _, rec in ipairs(records) do
    local end_lnum = clamp(rec.end_lnum or rec.lnum, line_count)
    if not groups[end_lnum] then
      groups[end_lnum] = {}
      table.insert(order, end_lnum)
    end
    table.insert(groups[end_lnum], rec)
  end
  table.sort(order)

  for _, end_lnum in ipairs(order) do
    local group = groups[end_lnum]
    table.sort(group, function(a, b)
      return a.lnum < b.lnum
    end)
    if show_body then
      vim.api.nvim_buf_set_extmark(buf, ns, end_lnum - 1, 0, {
        virt_lines = body_virt_lines(group, textoff),
        -- Starts the lines at window column 0 instead of the text column, so
        -- the block's gutter segment lands under the real sign/number
        -- columns rather than floating in the text area.
        virt_lines_leftcol = true,
        priority = SIGN_PRIORITY,
      })
    end
    for _, rec in ipairs(group) do
      place_record(buf, rec, line_count)
    end
  end
end

-- Reads back the current start/end extmark positions for `buf` and updates
-- any record whose range or anchored text has drifted since it was stored.
---@param buf integer
function Anchor.sync(buf)
  local ids = marks_by_buf[buf]
  if not ids or vim.tbl_isempty(ids) then
    return
  end
  local records = {}
  for _, rec in ipairs(Store.load()) do
    records[rec.id] = rec
  end

  -- ann_id -> { start = lnum, ["end"] = lnum }
  local positions = {}
  for mark_id, info in pairs(ids) do
    local pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, mark_id, {})
    if pos and pos[1] then
      positions[info.id] = positions[info.id] or {}
      positions[info.id][info.role] = pos[1] + 1
    end
  end

  for ann_id, pos in pairs(positions) do
    local rec = records[ann_id]
    if rec then
      local lnum = pos.start or pos["end"]
      local end_lnum = pos["end"] or lnum
      if end_lnum < lnum then
        end_lnum = lnum
      end
      local anchor_text = table.concat(vim.api.nvim_buf_get_lines(buf, lnum - 1, end_lnum, false), "\n")
      if lnum ~= rec.lnum or end_lnum ~= rec.end_lnum or anchor_text ~= rec.anchor_text then
        Store.update(ann_id, { lnum = lnum, end_lnum = end_lnum, anchor_text = anchor_text })
      end
    end
  end
end

function Anchor.toggle_body()
  show_body = not show_body
  for buf in pairs(marks_by_buf) do
    Anchor.render(buf)
  end
end

function Anchor.toggle_background()
  show_background = not show_background
  for buf in pairs(marks_by_buf) do
    Anchor.render(buf)
  end
end

-- Test-only: the namespace extmarks are drawn in, so a spec can inspect them
-- directly with `nvim_buf_get_extmarks`.
function Anchor._ns()
  return ns
end

-- Exposed so `ui.lua`'s picker list can prefix each item with the same state
-- glyph the buffer's sign column shows.
Anchor.record_state = record_state

function Anchor.setup()
  Config.on({ "BufReadPost", "BufEnter" }, function(ev)
    Anchor.render(ev.buf)
  end, "Render stored annotations for the buffer")

  Config.on("BufWritePost", function(ev)
    Anchor.sync(ev.buf)
    Anchor.render(ev.buf)
  end, "Sync drifted annotation positions back to the store")

  Config.on("User", "AnnotationsChanged", function()
    for buf in pairs(marks_by_buf) do
      Anchor.render(buf)
    end
  end, "Re-render annotations after a store mutation")

  Config.on("BufDelete", function(ev)
    marks_by_buf[ev.buf] = nil
  end, "Drop annotation extmark bookkeeping for the closed buffer")

  -- The gutter segment's width tracks the window's textoff, which none of
  -- the events above cover: a resize, a `number`/`signcolumn`/etc. toggle,
  -- or the same buffer opening in a second window with different gutter
  -- settings can all change it without touching the buffer itself.
  Config.on("WinResized", function(ev)
    for _, win in ipairs((ev.data and ev.data.windows) or {}) do
      if vim.api.nvim_win_is_valid(win) then
        Anchor.render(vim.api.nvim_win_get_buf(win))
      end
    end
  end, "Re-render annotation gutters after a window resize changes textoff")

  Config.on("OptionSet", { "number", "relativenumber", "signcolumn", "foldcolumn", "numberwidth" }, function()
    Anchor.render(vim.api.nvim_get_current_buf())
  end, "Re-render annotation gutters after a gutter-width option changes")

  Config.on("BufWinEnter", function(ev)
    Anchor.render(ev.buf)
  end, "Re-render when a buffer becomes visible in a (possibly new) window")
end

return Anchor
