-- The Docket: the list of changesets scheduled for review, the current
-- position within them, and the views onto them (diff views, outline). One
-- docket per review tab; owns the window topology (rows/left panes), the
-- save and index watchers, and its own lifecycle.
-- (Named to avoid conflation with nvim sessions.)

local Statusline = require("config.mini.statusline")
local staging = require("app.review.staging")
local parser = require("app.review.diff.parser")

---@class Review.Docket
---@field kind string
---@field cwd string
---@field title string
---@field win integer         row-1 primary window (dv)
---@field dv Review.DiffView  combined/unstaged role
---@field dv2 Review.DiffView staged role (window created on demand)
---@field source Review.Source
---@field changesets Review.Changeset[]
---@field files Review.FileChange[]  flattened across changesets, in changeset order
---@field cs_idx_by_id table<string, integer>
---@field idx integer
---@field state {outline_mode: string, layout: "inline"|"sbs", zoom: "split"|"combined"|"unstaged"|"staged", stack_order: "head-first"|"base-first"}
---@field outline table?  OutlineView (set by init.lua after construction)
---@field _win2 integer?  row-2 primary window (dv2), nil unless split is active
---@field _rendered {dv: Review.DiffView, file: Review.FileChange, role: string}[]
---@field _arranging boolean  suppresses WinClosed handlers during owned closes
---@field _win_aug integer    WinClosed handlers live here (cleared in destroy)
---@field _aug integer?     save-watcher augroup
---@field _timer userdata?  save-watcher debounce timer
---@field _index_ev userdata?  index-watcher fs_event
---@field _index_timer userdata?
---@field _collapse_timer userdata?  deferred row-2 collapse debounce timer
---@field _index_path string?
---@field _index_sig string?
---@field _closed boolean
local Docket = {}
Docket.__index = Docket

local M = {}

local ZOOM_ORDER = { "split", "combined", "unstaged", "staged" }

---@param opts {kind: string, cwd: string, title: string, win: integer, dv: Review.DiffView, dv2: Review.DiffView, source: Review.Source}
---@return Review.Docket
function M.new(opts)
  local self = setmetatable({}, Docket)
  self.kind = opts.kind
  self.cwd = opts.cwd
  self.title = opts.title
  self.win = opts.win
  self.dv = opts.dv
  self.dv2 = opts.dv2
  self.source = opts.source
  self.changesets = {}
  self.files = {}
  self.cs_idx_by_id = {}
  self.idx = 1
  self.state = {
    outline_mode = opts.source.default_outline_mode or "flat",
    layout = "inline",
    zoom = "split",
    stack_order = opts.source.default_stack_order or "head-first",
  }
  self.outline = nil
  self._win2 = nil
  self._rendered = {}
  self._arranging = false
  self._closed = false
  self._collapse_timer = nil
  self._win_aug = vim.api.nvim_create_augroup("ReviewDocketWins_" .. opts.dv.right.bufnr, { clear = true })
  self:_watch_primary()
  return self
end

-- Watch the row-1 primary for out-of-band closes: promote the staged row to
-- primary when it exists (otherwise the docket is windowless — the same
-- terminal state as pre-split single-window closes).
function Docket:_watch_primary()
  self:_watch_close(self.win, function()
    -- This row's left pane lost its primary either way.
    self:_drop_left(self.dv, true)
    if self._win2 and vim.api.nvim_win_is_valid(self._win2) then
      -- Promote row 2; the DiffView objects swap roles.
      self.dv, self.dv2 = self.dv2, self.dv
      self.win = self._win2
      self._win2 = nil
      self.state.zoom = "combined"
      self:_watch_primary()
    end
  end)
end

-- The adaptive zoom matrix: what actually renders for a file given the
-- requested zoom. Non-stageable files (source can't stage, or the file isn't
-- a worktree diff, or has no sub-diffs) always collapse to a plain combined
-- view; split keeps two rows only when both sub-diffs exist. Pure; exposed
-- for unit tests.
---@param can_stage boolean
---@param file Review.FileChange?
---@param zoom string
---@return boolean stageable
---@return string zoom_eff
function M._gate(can_stage, file, zoom)
  if not can_stage or not file or file.head_ref ~= "WORKTREE" then
    return false, "combined"
  end
  local u, s = file.unstaged ~= nil, file.staged_change ~= nil
  if not u and not s then
    return false, "combined"
  end
  if zoom == "split" then
    if u and s then
      return true, "split"
    end
    return true, u and "unstaged" or "staged"
  end
  if zoom == "unstaged" and not u then
    return true, "combined"
  end
  if zoom == "staged" and not s then
    return true, "combined"
  end
  return true, zoom
end

-- Flatten changesets into the nav list (changeset order). The outline renders
-- the grouped structure; the flat list is the ]f/[f nav model.
---@param changesets Review.Changeset[]?
function Docket:set_changesets(changesets)
  self.changesets = changesets or {}
  self.files = {}
  self.cs_idx_by_id = {}
  for i, cs in ipairs(self.changesets) do
    self.cs_idx_by_id[cs.id] = i
    for _, f in ipairs(cs.files) do
      table.insert(self.files, f)
    end
  end
end

-- Winbars for every pane. Right panes: title/changeset/position plus the
-- pane role when the staging split is meaningful; left (old-side) panes:
-- the rendered sub-file's path @ base ref.
function Docket:set_winbar()
  local file = self.files[self.idx]
  local prefix = "  REVIEW  " .. self.title
  local text = prefix
  if file then
    if #self.changesets > 1 then
      local ci = self.cs_idx_by_id[file.changeset_id]
      local cs = ci and self.changesets[ci]
      if cs then
        text = text .. ("  [%d/%d %s]"):format(ci, #self.changesets, cs.title)
      end
    end
    text = text .. ("  %s (%d/%d)"):format(file.path, self.idx, #self.files)
  end

  local function set(win, t)
    if win and vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winbar = Statusline.make_winbar(t, "MiniStatuslineModeNormal")
    end
  end

  if #self._rendered == 0 then
    set(self.win, text)
    return
  end
  for _, r in ipairs(self._rendered) do
    local role = r.role ~= "plain" and ("  " .. r.role:upper()) or ""
    set(r.dv.right.win, (r.dv == self.dv and text or prefix) .. role)
    if r.dv.left:win_valid() then
      local base = r.file and r.file.base_ref
      if not base or base == "" then
        base = "HEAD"
      end
      local lpath = r.file and (r.file.old_path or r.file.path) or ""
      set(r.dv.left.win, prefix .. role .. ("  %s @ %s"):format(lpath, base))
    end
  end
end

-- ── Window topology ─────────────────────────────────────────────────────────
-- The docket owns all managed windows: self.win (row 1, dv), _win2 (row 2,
-- dv2, split zoom only), and each row's left pane (sbs layout). DiffViews
-- render into whatever they're bound to; binding teardown happens BEFORE
-- windows close.

-- Unbind and close a row's left pane. set_layout("inline") only unbinds —
-- the docket owns the window itself, so every collapse site funnels here.
---@param dv Review.DiffView
---@param safe boolean?  pcall the close (WinClosed handler contexts)
function Docket:_drop_left(dv, safe)
  local left = dv.left.win
  dv:set_layout("inline")
  if left and vim.api.nvim_win_is_valid(left) then
    if safe then
      pcall(vim.api.nvim_win_close, left, false)
    else
      vim.api.nvim_win_close(left, false)
    end
  end
end

-- One WinClosed handler per managed window: an out-of-band close (:q in a
-- pane) re-syncs docket state and re-applies the arrangement. Owned closes
-- run under `_arranging` and are ignored. Handlers live in the docket's
-- augroup so destroy() clears any that never fired (their closures would
-- otherwise pin the docket for the session).
---@param win integer
---@param on_gone fun()
function Docket:_watch_close(win, on_gone)
  vim.api.nvim_create_autocmd("WinClosed", {
    group = self._win_aug,
    pattern = tostring(win),
    once = true,
    callback = function()
      if self._closed or self._arranging then
        return
      end
      on_gone()
      vim.schedule(function()
        if not self._closed then
          self:show_file(self:_saved_view())
        end
      end)
    end,
  })
end

function Docket:_saved_view()
  return vim.api.nvim_win_is_valid(self.win) and vim.api.nvim_win_call(self.win, vim.fn.winsaveview) or nil
end

-- Ensure the window set matches (rows, layout). Idempotent; restores focus.
-- Returns false when the arrangement couldn't be built (E36 in a cramped
-- terminal, cmdline-window) so callers can revert the state that wanted it.
---@param rows integer  1 or 2
---@param opts { keep_row2?: boolean }?  keep_row2 freezes row 2 open even when rows == 1
---  (used to defer the collapse so a scan across mixed partial/clean files doesn't thrash
---  the window); the caller is responsible for blanking row 2's content and scheduling the
---  real collapse.
---@return boolean
function Docket:_arrange(rows, opts)
  if not vim.api.nvim_win_is_valid(self.win) then
    return false
  end
  -- Refreshes can fire while another tab is current (embedded mode); window
  -- surgery there would yank the user's tab. Render into the existing
  -- windows and let the next interaction in the review tab re-arrange.
  if vim.api.nvim_win_get_tabpage(self.win) ~= vim.api.nvim_get_current_tabpage() then
    return true
  end
  self._arranging = true
  local prev = vim.api.nvim_get_current_win()

  -- Splits can throw (E36, no room); the flag and focus must be restored on
  -- every exit or all WinClosed re-sync handlers go permanently dead.
  local changed = false
  local ok, err = pcall(function()
    -- Row 2 (staged pane).
    local have2 = self._win2 and vim.api.nvim_win_is_valid(self._win2)
    if rows == 2 and not have2 then
      -- In sbs, self.win is only the right column; a split there would hang
      -- row 2 under that column. Drop row 1's left pane so the split spans
      -- the diff area — the loop below re-creates both rows' left panes.
      if self.dv.left:win_valid() then
        self:_drop_left(self.dv)
      end
      vim.api.nvim_set_current_win(self.win)
      vim.cmd("belowright split")
      changed = true
      self._win2 = vim.api.nvim_get_current_win()
      self.dv2:bind_primary(self._win2)
      self:_watch_close(self._win2, function()
        self._win2 = nil
        self.state.zoom = "combined"
        -- The row's left pane has no primary anymore; drop it too.
        self:_drop_left(self.dv2, true)
      end)
    elseif rows == 1 and have2 and not (opts and opts.keep_row2) then
      self:_drop_left(self.dv2)
      vim.api.nvim_win_close(self._win2, false)
      self._win2 = nil
      changed = true
    end

    -- Left panes per active row.
    local active = { { self.dv, self.win } }
    if rows == 2 then
      table.insert(active, { self.dv2, self._win2 })
    end
    for _, pair in ipairs(active) do
      local dv, primary = pair[1], pair[2]
      local have_left = dv.left:win_valid()
      if self.state.layout == "sbs" and not have_left then
        vim.api.nvim_set_current_win(primary)
        vim.cmd("leftabove vsplit")
        changed = true
        local left = vim.api.nvim_get_current_win()
        dv:set_layout("sbs", left)
        self:_watch_close(left, function()
          dv:set_layout("inline")
          self.state.layout = "inline"
        end)
      elseif self.state.layout ~= "sbs" and have_left then
        self:_drop_left(dv)
        changed = true
      end
    end

    -- Equalize once after all topology changes; never on a no-op arrange,
    -- which would reflow user-adjusted window sizes on every file nav.
    -- win_equal alone isn't trusted: it distributes rounding leftovers
    -- unevenly across sibling rows beside a winfixwidth sidebar (vsplit
    -- points misalign), and in this config it can leave the rows' heights
    -- outright unequal — pin row 1 to half explicitly; row 2 absorbs the
    -- remainder.
    if changed then
      vim.cmd("wincmd =")
      local w2 = self._win2
      if w2 and vim.api.nvim_win_is_valid(w2) then
        local total = vim.api.nvim_win_get_height(self.win) + vim.api.nvim_win_get_height(w2)
        vim.api.nvim_win_set_height(self.win, math.floor(total / 2))
      end
      if self.dv.left:win_valid() and self.dv2.left:win_valid() then
        vim.api.nvim_win_set_width(self.dv2.left.win, vim.api.nvim_win_get_width(self.dv.left.win))
      end
    end
  end)

  if vim.api.nvim_win_is_valid(prev) then
    vim.api.nvim_set_current_win(prev)
  elseif vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_set_current_win(self.win)
  end
  self._arranging = false
  if not ok then
    self:_notify("Review: window arrange failed: " .. tostring(err), vim.log.levels.WARN)
  end
  return ok
end

-- Cancel a pending deferred row-2 collapse, if any. Call whenever a file
-- wants row 2 open (either kept or freshly created) so a stale timer from an
-- earlier clean file can't close it out from under the new render.
function Docket:_cancel_collapse()
  if self._collapse_timer then
    self._collapse_timer:stop()
    self._collapse_timer:close()
    self._collapse_timer = nil
  end
end

-- Arm the deferred row-2 collapse. show_file calls this after landing on a
-- 1-row file while row 2 is still open (kept alive via _arrange(1, {
-- keep_row2 = true }) so a scan across mixed partial/clean files doesn't
-- thrash the window). Fires once, idle; re-checks the gate at fire time
-- since the current file may have changed again by then.
function Docket:_schedule_collapse()
  self:_cancel_collapse()
  self._collapse_timer = vim.uv.new_timer()
  self._collapse_timer:start(200, 0, function()
    if self._collapse_timer then
      self._collapse_timer:close()
      self._collapse_timer = nil
    end
    vim.schedule(function()
      if self._closed then
        return
      end
      local _, zoom_eff = M._gate(self.source:can_stage(), self.files[self.idx], self.state.zoom)
      if zoom_eff ~= "split" and self._win2 and vim.api.nvim_win_is_valid(self._win2) then
        self:_arrange(1)
        self:set_winbar()
      end
    end)
  end)
end

-- Toggle inline ↔ side-by-side. Layout persists across file nav. When the
-- arrangement can't be built (E36), the state change is rolled back so a
-- single retry after freeing space works.
function Docket:toggle_layout()
  if not vim.api.nvim_win_is_valid(self.win) then
    return
  end
  local view = self:_saved_view()
  local prior = self.state.layout
  self.state.layout = prior == "inline" and "sbs" or "inline"
  if not self:show_file(view) then
    self.state.layout = prior
  end
end

-- Cycle the staging zoom: split → combined → unstaged → staged.
function Docket:cycle_zoom()
  if not self:_can_stage_or_notify() then
    return
  end
  local prior = self.state.zoom
  for i, z in ipairs(ZOOM_ORDER) do
    if z == prior then
      self.state.zoom = ZOOM_ORDER[(i % #ZOOM_ORDER) + 1]
      break
    end
  end
  if not self:show_file() then
    self.state.zoom = prior
    return
  end
  self:_notify("Review zoom: " .. self.state.zoom)
end

-- Role plan builders keyed by the gate's already-collapsed zoom_eff: what
-- each active DiffView renders. The "combined" case (no entry here) is the
-- only one that depends on stageable, so it stays a fallback below rather
-- than forcing every branch through that check.
local ZOOM_PLANS = {
  split = function(self, file)
    return {
      { dv = self.dv, file = file.unstaged, role = "unstaged", mode = "plain" },
      { dv = self.dv2, file = file.staged_change, role = "staged", mode = "staged" },
    }
  end,
  unstaged = function(self, file)
    return { { dv = self.dv, file = file.unstaged, role = "unstaged", mode = "plain" } }
  end,
  staged = function(self, file)
    return { { dv = self.dv, file = file.staged_change, role = "staged", mode = "staged" } }
  end,
}

-- Render the file at self.idx into the arrangement the gate dictates.
-- view: optional winsaveview() to restore (refresh path); otherwise the
-- cursor jumps to the first hunk. Returns false when the window arrangement
-- couldn't be built (nothing was rendered).
---@return boolean
function Docket:show_file(view)
  local file = self.files[self.idx]
  if not file then
    return true
  end
  local stageable, zoom_eff = M._gate(self.source:can_stage(), file, self.state.zoom)
  if zoom_eff == "split" then
    self:_cancel_collapse()
    if not self:_arrange(2) then
      return false
    end
  elseif self._win2 and vim.api.nvim_win_is_valid(self._win2) then
    -- Row 2 is open but this file only wants 1 row. Keep the split geometry
    -- (avoids the close/reopen pop when a scan flips back to a partial file)
    -- and blank row 2's content; the deferred collapse tears it down only if
    -- the user is still settled here once the debounce elapses.
    if not self:_arrange(1, { keep_row2 = true }) then
      return false
    end
    self.dv2:blank()
    self:_schedule_collapse()
  else
    self:_cancel_collapse()
    if not self:_arrange(1) then
      return false
    end
  end

  -- (When stageable, the gate guarantees at least one sub-diff exists, so
  -- combined is attributed.)
  local build_plan = ZOOM_PLANS[zoom_eff]
  local plan = build_plan and build_plan(self, file)
    or { { dv = self.dv, file = file, role = stageable and "combined" or "plain", mode = stageable and "attributed" or "plain" } }
  self._rendered = plan

  for _, r in ipairs(plan) do
    if r.dv == self.dv then
      -- Primary render drives winbar + cursor restore.
      r.dv:render(r.file, self.cwd, function()
        if self._closed or not vim.api.nvim_win_is_valid(self.win) then
          return
        end
        self:set_winbar()
        vim.api.nvim_win_call(self.win, function()
          if view then
            vim.fn.winrestview(view)
          else
            local hr = self.dv.right.hunk_rows[1]
            if hr then
              self.dv:reveal(self.win, hr.first_diff + 1)
            end
          end
          -- API cursor/view changes don't run scrollbind; re-anchor the left
          -- pane so both panes show the same region after a restore.
          if self.dv.left:win_valid() then
            vim.cmd("syncbind")
          end
        end)
      end, r.mode)
    else
      -- Non-primary render: no winbar/cursor here (the primary owns those),
      -- but re-anchor its left pane once settled so completion is a
      -- callback signal rather than something callers poll _rendered_file
      -- (or buffer contents) for.
      r.dv:render(r.file, self.cwd, function()
        if self._closed or not r.dv.right:win_valid() then
          return
        end
        if r.dv.left:win_valid() then
          vim.api.nvim_win_call(r.dv.right.win, function()
            vim.cmd("syncbind")
          end)
        end
      end, r.mode)
    end
  end
  if self.outline then
    self.outline:sync_to_current(file)
  end
  return true
end

-- Focus a specific FileChange (object identity — the same path can appear in
-- several changesets). No-op when the file is already current or unknown.
---@param file Review.FileChange
function Docket:focus_file(file)
  for i, f in ipairs(self.files) do
    if f == file then
      if i ~= self.idx then
        self.idx = i
        self:show_file()
      end
      return
    end
  end
end

---@return Review.FileChange?
function Docket:current_file()
  return self.files[self.idx]
end

function Docket:next_file()
  if self.idx < #self.files then
    self.idx = self.idx + 1
    self:show_file()
  end
end

function Docket:prev_file()
  if self.idx > 1 then
    self.idx = self.idx - 1
    self:show_file()
  end
end

-- The DiffView whose pane holds the given (or current) window; defaults to
-- the primary. Also returns that view's primary window for cursor ops.
---@param win integer?
---@return Review.DiffView dv, integer win
function Docket:_dv_for_win(win)
  win = win or vim.api.nvim_get_current_win()
  for _, dv in ipairs({ self.dv, self.dv2 }) do
    if dv:pane_for_win(win) then
      return dv, dv.right.win
    end
  end
  return self.dv, self.win
end

-- Jump to the first diff line of the next/prev hunk in the row the cursor is
-- in; clamps at the ends. Cursor reads are anchored to the row's primary
-- window so the methods behave identically from a left pane.
function Docket:next_hunk()
  local dv, win = self:_dv_for_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(win)[1] - 1
  for _, hr in ipairs(dv.right.hunk_rows) do
    if hr.s > row then
      dv:reveal(win, hr.first_diff + 1)
      return
    end
  end
end

function Docket:prev_hunk()
  local dv, win = self:_dv_for_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(win)[1] - 1
  local target = nil
  for _, hr in ipairs(dv.right.hunk_rows) do
    if hr.e < row then
      target = hr
    end
  end
  if target then
    dv:reveal(win, target.first_diff + 1)
  end
end

-- Jump to the first file of the next/prev changeset; clamps at the ends.
function Docket:next_changeset()
  local file = self.files[self.idx]
  local ci = file and self.cs_idx_by_id[file.changeset_id] or 0
  for i = self.idx + 1, #self.files do
    if self.cs_idx_by_id[self.files[i].changeset_id] > ci then
      self.idx = i
      self:show_file()
      return
    end
  end
end

function Docket:prev_changeset()
  local file = self.files[self.idx]
  local ci = file and self.cs_idx_by_id[file.changeset_id] or 0
  if ci <= 1 then
    return
  end
  for i = 1, #self.files do
    if self.cs_idx_by_id[self.files[i].changeset_id] == ci - 1 then
      self.idx = i
      self:show_file()
      return
    end
  end
end

-- ── Staging actions ─────────────────────────────────────────────────────────
-- Hunk ops are pane-scoped: they resolve the hunk under the cursor in the
-- pane's rendered sub-diff. The combined view mixes both sub-diffs' rows, so
-- hunk ops there point at split/zoom instead (the POC's combined-pane role
-- mapping indexed the wrong hunk list).

-- The rendered (dv, sub-file, role) entry for the current window, or nil.
function Docket:_pane_at_cursor()
  local cur = vim.api.nvim_get_current_win()
  for _, r in ipairs(self._rendered) do
    if r.dv:pane_for_win(cur) then
      return r, cur
    end
  end
end

function Docket:_notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Review" })
end

-- Destructive-op confirmation; an instance field so tests can stub it
-- (vim.fn.confirm can't be monkeypatched — vim.fn is a magic table).
function Docket:_confirm(msg)
  return vim.fn.confirm(msg, "&Yes\n&No", 2) == 1
end

---@return boolean
function Docket:_can_stage_or_notify()
  if self.source:can_stage() then
    return true
  end
  self:_notify("Review: nothing stageable here")
  return false
end

-- Guard shared by every staging action.
---@return Review.FileChange?
function Docket:_stageable_file()
  local file = self.files[self.idx]
  if not self:_can_stage_or_notify() then
    return nil
  end
  if not file or file.head_ref ~= "WORKTREE" then
    self:_notify("Review: nothing stageable here")
    return nil
  end
  return file
end

-- Post-op refresh, once per queue drain: rapid staging enqueues N git ops
-- but only the last one's completion triggers the (expensive) refresh.
function Docket:_after_stage_op()
  self._stage_done = self._stage_done or function()
    if not self._closed and staging._queue_len() == 0 then
      self:refresh()
    end
  end
  return self._stage_done
end

-- Shared guard for cursor-scoped staging ops: the pane must have a staged/
-- unstaged role, and its async render must have caught up with the plan —
-- stale hunk objects belong to the previously rendered file. Notifies and
-- returns nil otherwise.
---@param what string  op label for the role notify
function Docket:_ready_pane(what)
  local r, cur = self:_pane_at_cursor()
  if not r or (r.role ~= "unstaged" and r.role ~= "staged") then
    self:_notify("Review: " .. what .. " needs an unstaged/staged pane — cycle zoom (<leader>rz)")
    return nil
  end
  if r.dv._rendered_file ~= r.file then
    self:_notify("Review: still rendering — try again")
    return nil
  end
  return r, cur
end

-- The hunk under the cursor in a staged/unstaged pane, or nil (notifies).
function Docket:_hunk_at_cursor()
  local r, cur = self:_ready_pane("hunk staging")
  if not r then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(cur)[1] - 1
  local hunk = r.dv:hunk_at(cur, row)
  if not hunk then
    self:_notify("Review: no hunk under cursor")
    return nil
  end
  return r, hunk
end

-- Whole-file statuses can't be staged hunk-wise: hunk_to_patch reconstructs
-- plain a/-b/ headers, but creations/deletions need /dev/null + file-mode
-- header lines. The only meaningful granularity is the file anyway.
local function hunkwise(sub)
  return sub.status == "M" or sub.status == "R"
end

-- Stage the hunk under the cursor; in the staged pane this unstages instead
-- (pane-aware toggle). Untracked/added/deleted sub-files fall back to the
-- equivalent file-level op.
function Docket:stage_current()
  local file = self:_stageable_file()
  if not file then
    return
  end
  local r, hunk = self:_hunk_at_cursor()
  if not r then
    return
  end
  if r.role == "staged" then
    if hunkwise(r.file) then
      staging.unstage_hunk(self.cwd, r.file, hunk, self:_after_stage_op())
    else
      staging.unstage_file(self.cwd, file.path, self:_after_stage_op())
    end
  else
    if hunkwise(r.file) then
      staging.stage_hunk(self.cwd, r.file, hunk, self:_after_stage_op())
    else
      staging.stage_file(self.cwd, file.path, self:_after_stage_op())
    end
  end
end

-- Discard the hunk under the cursor from the worktree (unstaged pane only).
function Docket:discard_current()
  local file = self:_stageable_file()
  if not file then
    return
  end
  local r, hunk = self:_hunk_at_cursor()
  if not r then
    return
  end
  if r.role ~= "unstaged" then
    self:_notify("Review: discard acts in the unstaged pane")
    return
  end
  if not hunkwise(r.file) then
    self:discard_file(file)
    return
  end
  if not self:_confirm("Discard this hunk from the worktree?") then
    return
  end
  staging.discard_hunk(self.cwd, r.file, hunk, self:_after_stage_op())
end

-- Selection context for the line-precise ops: the pane entry, its side, the
-- selected source-line range, and the hunks the rows overlap. Row arguments
-- are 1-based buffer lines captured from the visual selection.
---@param row_lo integer
---@param row_hi integer
---@return {r: table, side: "LEFT"|"RIGHT", lo: integer, hi: integer, hunks: Review.Hunk[]}?
function Docket:_selection_at_cursor(row_lo, row_hi)
  local r, cur = self:_ready_pane("line staging")
  if not r then
    return nil
  end
  -- hunk_to_patch_lines headers can't express creations/deletions any more
  -- than hunk_to_patch can. The hunk ops widen to file-level there; widening
  -- a 3-line selection to the whole file would surprise, so refuse instead.
  if not hunkwise(r.file) then
    self:_notify("Review: line staging needs a modified file — use the file ops")
    return nil
  end
  local info_lo = r.dv:row_to_source(cur, row_lo - 1)
  local info_hi = r.dv:row_to_source(cur, row_hi - 1)
  local hunks = r.dv:hunks_in_range(cur, row_lo - 1, row_hi - 1)
  if not (info_lo and info_hi) or #hunks == 0 then
    self:_notify("Review: no hunk in selection")
    return nil
  end
  return { r = r, side = info_lo.side, lo = info_lo.lnum, hi = info_hi.lnum, hunks = hunks }
end

-- Per-hunk predicate plans for a selection; hunks the selection only grazes
-- (context rows, nothing kept) are skipped. Notifies and returns nil when
-- nothing in the span is a changed line. `lines` totals the kept add/del
-- lines so destructive prompts can state their true scope.
---@return {plans: {hunk: Review.Hunk, keep_add: function, keep_del: function}[], lines: integer}?
function Docket:_selection_plans(sel)
  local plans = {}
  local lines = 0
  for _, hunk in ipairs(sel.hunks) do
    local keep_add, keep_del, kept = parser.line_predicates(hunk, sel.side, sel.lo, sel.hi)
    if kept > 0 then
      table.insert(plans, { hunk = hunk, keep_add = keep_add, keep_del = keep_del })
      lines = lines + kept
    end
  end
  if #plans == 0 then
    self:_notify("Review: no changed lines in selection")
    return nil
  end
  return { plans = plans, lines = lines }
end

-- Stage the visually selected lines; in the staged pane this unstages them
-- (pane-aware toggle, matching stage_current).
---@param row_lo integer
---@param row_hi integer
function Docket:stage_selection(row_lo, row_hi)
  local file = self:_stageable_file()
  if not file then
    return
  end
  local sel = self:_selection_at_cursor(row_lo, row_hi)
  if not sel then
    return
  end
  local sp = self:_selection_plans(sel)
  if not sp then
    return
  end
  for _, p in ipairs(sp.plans) do
    if sel.r.role == "staged" then
      staging.unstage_lines(self.cwd, sel.r.file, p.hunk, p.keep_add, p.keep_del, self:_after_stage_op())
    else
      staging.stage_lines(self.cwd, sel.r.file, p.hunk, p.keep_add, p.keep_del, self:_after_stage_op())
    end
  end
end

-- Discard the visually selected lines from the worktree (unstaged pane only).
---@param row_lo integer
---@param row_hi integer
function Docket:discard_selection(row_lo, row_hi)
  local file = self:_stageable_file()
  if not file then
    return
  end
  local sel = self:_selection_at_cursor(row_lo, row_hi)
  if not sel then
    return
  end
  if sel.r.role ~= "unstaged" then
    self:_notify("Review: discard acts in the unstaged pane")
    return
  end
  local sp = self:_selection_plans(sel)
  if not sp then
    return
  end
  -- State the true scope: a linewise `j` over a closed context fold jumps
  -- whole hunks, so the span can cover far more than what looked selected.
  local msg = ("Discard %d line%s across %d hunk%s from the worktree?"):format(
    sp.lines,
    sp.lines == 1 and "" or "s",
    #sp.plans,
    #sp.plans == 1 and "" or "s"
  )
  if not self:_confirm(msg) then
    return
  end
  for _, p in ipairs(sp.plans) do
    staging.discard_lines(self.cwd, sel.r.file, p.hunk, p.keep_add, p.keep_del, self:_after_stage_op())
  end
end

-- Stage the current file; in the staged pane this unstages it instead.
function Docket:stage_current_file()
  local file = self:_stageable_file()
  if not file then
    return
  end
  local r = self:_pane_at_cursor()
  if r and r.role == "staged" then
    staging.unstage_file(self.cwd, file.path, self:_after_stage_op())
  else
    staging.stage_file(self.cwd, file.path, self:_after_stage_op())
  end
end

function Docket:discard_current_file()
  local file = self:_stageable_file()
  if not file then
    return
  end
  self:discard_file(file)
end

-- File-object-driven variants for the outline (no diff-cursor dependency).
---@param change Review.FileChange
function Docket:toggle_stage_file(change)
  if not self:_can_stage_or_notify() then
    return
  end
  -- Direction comes from the live index inside the queued op, not from
  -- `change.staged`: outline items survive refreshes, so the snapshot can
  -- be stale and a wrong-direction toggle silently no-ops.
  staging.toggle_file(self.cwd, change.path, self:_after_stage_op())
end

-- Stage/unstage a whole directory subtree (outline dir rows), same
-- live-state toggle convention as toggle_stage_file/toggle_all.
---@param dir string
function Docket:toggle_stage_tree(dir)
  if not self:_can_stage_or_notify() then
    return
  end
  staging.toggle_tree(self.cwd, dir, self:_after_stage_op())
end

---@param change Review.FileChange
function Docket:discard_file(change)
  if not self:_can_stage_or_notify() then
    return
  end
  local verb = change.status == "U" and "Delete untracked" or "Discard all worktree changes to"
  if not self:_confirm(("%s %s?"):format(verb, change.path)) then
    return
  end
  if change.status == "U" then
    staging.delete_untracked(self.cwd, change.path, self:_after_stage_op())
  else
    -- A partially staged file may also need its index entry reset first;
    -- git restore only touches the worktree, which is the lazygit behavior.
    staging.discard_file(self.cwd, change.path, self:_after_stage_op())
  end
end

-- Stage everything if anything is unstaged, otherwise unstage everything.
function Docket:toggle_all()
  if not self:_can_stage_or_notify() then
    return
  end
  staging.toggle_all(self.cwd, self:_after_stage_op())
end

-- Initial load: fetch changesets, open at the current-position changeset
-- (the source marks it), start the save watcher.
function Docket:load()
  self.source:load(function(changesets, err)
    if self._closed then
      return
    end
    if err then
      self.dv:_render_placeholder("[Review error: " .. err .. "]")
      return
    end
    self:set_changesets(changesets)
    if #self.files == 0 then
      self.dv:_render_placeholder("[No changes]")
      return
    end
    for i, f in ipairs(self.files) do
      local ci = self.cs_idx_by_id[f.changeset_id]
      if ci and self.changesets[ci].current then
        self.idx = i
        break
      end
    end
    if self.outline then
      self.outline:render()
    end
    self:show_file()
    self:_start_watcher()
    self:_start_index_watcher()
  end)
end

function Docket:refresh()
  local current = self.files[self.idx]
  local current_path = current and current.path
  local current_cs = current and current.changeset_id
  -- Refreshes can overlap (staging op completion + watchers); only the
  -- newest one's completion may apply, or a slow stale read overwrites
  -- fresh data last-writer-wins.
  self._refresh_seq = (self._refresh_seq or 0) + 1
  local seq = self._refresh_seq
  -- Snapshot at start too: a staging op's index write already scheduled the
  -- watcher's debounce; without this a slow refresh (>300ms) gets doubled.
  self:_snapshot_index_sig()
  self.source:refresh(function(changesets, err)
    if self._closed then
      return
    end
    -- Re-snapshot the index signature BEFORE the supersede check: this
    -- refresh's own `git diff` rewrote the index stat cache regardless of
    -- who wins. Skipping the snapshot on a superseded completion lets the
    -- fs_event echo schedule yet another refresh, whose completion then
    -- supersedes the next one — a self-sustaining loop under staging storms
    -- where NO completion ever applies and dk.files stays arbitrarily stale
    -- (found by the line-staging e2e: files were minutes old).
    -- Tradeoff (accepted): the snapshot reads the LIVE index sig, so an
    -- external write landing in this window can be misread as our own echo
    -- and its watcher event dropped. Winning completions always had that
    -- window; forward progress beats narrowing it.
    self:_snapshot_index_sig()
    if seq ~= self._refresh_seq then
      return
    end
    if err then
      vim.notify("Review refresh error: " .. err, vim.log.levels.ERROR, { title = "Review" })
      return
    end
    self:set_changesets(changesets)
    if self.outline then
      self.outline:render()
    end
    if #self.files == 0 then
      self.idx = 1
      self._rendered = {}
      self:_arrange(1)
      self.dv:_render_placeholder("[No changes]")
      self:set_winbar()
      return
    end
    -- Keep the current file when it still exists (same path can appear in
    -- several changesets, so match both); clamp the index otherwise.
    local same_file = false
    if current_path then
      for i, f in ipairs(self.files) do
        if f.path == current_path and f.changeset_id == current_cs then
          self.idx = i
          same_file = true
          break
        end
      end
    end
    if not same_file then
      self.idx = math.min(self.idx, #self.files)
    end
    local view = same_file
        and vim.api.nvim_win_is_valid(self.win)
        and vim.api.nvim_win_call(self.win, vim.fn.winsaveview)
      or nil
    self:show_file(view)
  end)
end

-- Debounced refresh on file saves under the repo root and on focus regain
-- (external edits). The augroup is global, not buffer-local: writes happen in
-- other buffers (embedded mode), never in the review buffer itself.
function Docket:_start_watcher()
  local cwd = vim.fs.normalize(self.cwd)
  self._aug = vim.api.nvim_create_augroup("ReviewSaveWatch_" .. self.dv.right.bufnr, { clear = true })

  local function schedule_refresh()
    if self._timer then
      self._timer:stop()
      self._timer:close()
    end
    self._timer = vim.uv.new_timer()
    self._timer:start(250, 0, function()
      if self._timer then
        self._timer:close()
        self._timer = nil
      end
      vim.schedule(function()
        if not self._closed then
          self:refresh()
        end
      end)
    end)
  end

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = self._aug,
    callback = function(ev)
      local path = vim.api.nvim_buf_get_name(ev.buf)
      if path == "" or vim.fs.normalize(path):sub(1, #cwd) ~= cwd then
        return
      end
      schedule_refresh()
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = self._aug,
    callback = schedule_refresh,
  })
end

function Docket:_stop_watcher()
  if self._timer then
    self._timer:stop()
    self._timer:close()
    self._timer = nil
  end
  if self._aug then
    pcall(vim.api.nvim_del_augroup_by_id, self._aug)
    self._aug = nil
  end
end

-- Watch .git/index for external staging (lazygit, CLI). fs_event on macOS
-- fires at directory granularity, so unrelated `git` subprocesses produce
-- spurious events — the mtime:nsec:size signature filters them (checked at
-- event time AND at debounce fire, collapsing the echo of our own staging
-- ops, whose refresh re-snapshots the signature).
local function index_sig(path)
  local st = path and vim.uv.fs_stat(path)
  return st and ("%d:%d:%d"):format(st.mtime.sec, st.mtime.nsec, st.size) or nil
end

function Docket:_snapshot_index_sig()
  if self._index_path then
    self._index_sig = index_sig(self._index_path)
  end
end

function Docket:_start_index_watcher()
  if not self.source:can_stage() then
    return
  end
  -- The index is per-worktree: resolve via --git-dir (async — nothing awaits
  -- the watcher, and a cold git spawn would stall the open path).
  require("app.review.diff.git").git_dir(self.cwd, function(gitdir)
    if self._closed or not gitdir then
      return
    end
    self._index_path = gitdir .. "/index"
    self._index_sig = index_sig(self._index_path)

    self._index_ev = vim.uv.new_fs_event()
    if not self._index_ev then
      return
    end
    self._index_ev:start(self._index_path, {}, function()
      vim.schedule(function()
        if self._closed or index_sig(self._index_path) == self._index_sig then
          return
        end
        if self._index_timer then
          self._index_timer:stop()
          self._index_timer:close()
        end
        self._index_timer = vim.uv.new_timer()
        self._index_timer:start(300, 0, function()
          if self._index_timer then
            self._index_timer:close()
            self._index_timer = nil
          end
          vim.schedule(function()
            if self._closed or index_sig(self._index_path) == self._index_sig then
              return
            end
            self:refresh()
          end)
        end)
      end)
    end)
  end)
end

function Docket:_stop_index_watcher()
  if self._index_timer then
    self._index_timer:stop()
    self._index_timer:close()
    self._index_timer = nil
  end
  if self._index_ev then
    self._index_ev:stop()
    self._index_ev:close()
    self._index_ev = nil
  end
end

function Docket:destroy()
  if self._closed then
    return
  end
  self._closed = true
  self:_stop_watcher()
  self:_stop_index_watcher()
  self:_cancel_collapse()
  pcall(vim.api.nvim_del_augroup_by_id, self._win_aug)
  if self.outline then
    self.outline:destroy()
    self.outline = nil
  end
  self._arranging = true
  if self._win2 and vim.api.nvim_win_is_valid(self._win2) then
    pcall(vim.api.nvim_win_close, self._win2, true)
  end
  self._win2 = nil
  self.dv:destroy()
  self.dv2:destroy()
end

return M
