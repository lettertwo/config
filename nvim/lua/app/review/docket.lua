-- The Docket: the list of changesets scheduled for review, the current
-- position within them, and the views onto them (diff view, outline). One
-- docket per review tab; owns the save watcher and its own lifecycle.
-- (Named to avoid conflation with nvim sessions.)

local Statusline = require("config.mini.statusline")

---@class Review.Docket
---@field kind string
---@field cwd string
---@field title string
---@field win integer
---@field dv Review.DiffView
---@field source Review.Source
---@field changesets Review.Changeset[]
---@field files Review.FileChange[]  flattened across changesets, in changeset order
---@field cs_idx_by_id table<string, integer>
---@field idx integer
---@field state {outline_mode: string}
---@field outline table?  OutlineView (set by init.lua after construction)
---@field _aug integer?     save-watcher augroup
---@field _timer userdata?  save-watcher debounce timer
---@field _closed boolean
local Docket = {}
Docket.__index = Docket

local M = {}

---@param opts {kind: string, cwd: string, title: string, win: integer, dv: Review.DiffView, source: Review.Source}
---@return Review.Docket
function M.new(opts)
  local self = setmetatable({}, Docket)
  self.kind = opts.kind
  self.cwd = opts.cwd
  self.title = opts.title
  self.win = opts.win
  self.dv = opts.dv
  self.source = opts.source
  self.changesets = {}
  self.files = {}
  self.cs_idx_by_id = {}
  self.idx = 1
  self.state = { outline_mode = opts.source.default_outline_mode or "flat" }
  self.outline = nil
  self._closed = false
  return self
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

function Docket:set_winbar()
  if not vim.api.nvim_win_is_valid(self.win) then
    return
  end
  local text = "  REVIEW  " .. self.title
  local file = self.files[self.idx]
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
  vim.wo[self.win].winbar = Statusline.make_winbar(text, "MiniStatuslineModeNormal")
end

-- Render the file at self.idx. view: optional winsaveview() to restore
-- (refresh path); otherwise the cursor jumps to the first hunk.
function Docket:show_file(view)
  local file = self.files[self.idx]
  if not file then
    return
  end
  self.dv:render(file, self.cwd, function()
    if self._closed or not vim.api.nvim_win_is_valid(self.win) then
      return
    end
    self:set_winbar()
    vim.api.nvim_win_call(self.win, function()
      if view then
        vim.fn.winrestview(view)
      else
        local hr = self.dv.hunk_rows[1]
        if hr then
          vim.api.nvim_win_set_cursor(self.win, { hr.first_diff + 1, 0 })
          vim.cmd("normal! zv")
        end
      end
    end)
  end)
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

-- Jump to the first diff line of the next/prev hunk; clamps at the ends.
function Docket:next_hunk()
  local row = vim.fn.line(".") - 1
  for _, hr in ipairs(self.dv.hunk_rows) do
    if hr.s > row then
      vim.api.nvim_win_set_cursor(self.win, { hr.first_diff + 1, 0 })
      vim.cmd("normal! zv")
      return
    end
  end
end

function Docket:prev_hunk()
  local row = vim.fn.line(".") - 1
  local target = nil
  for _, hr in ipairs(self.dv.hunk_rows) do
    if hr.e < row then
      target = hr
    end
  end
  if target then
    vim.api.nvim_win_set_cursor(self.win, { target.first_diff + 1, 0 })
    vim.cmd("normal! zv")
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
    self:show_file()
    if self.outline then
      self.outline:render()
    end
    self:_start_watcher()
  end)
end

function Docket:refresh()
  local current = self.files[self.idx]
  local current_path = current and current.path
  local current_cs = current and current.changeset_id
  self.source:refresh(function(changesets, err)
    if self._closed then
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
  self._aug = vim.api.nvim_create_augroup("ReviewSaveWatch_" .. self.dv.bufnr, { clear = true })

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

function Docket:destroy()
  if self._closed then
    return
  end
  self._closed = true
  self:_stop_watcher()
  if self.outline then
    self.outline:destroy()
    self.outline = nil
  end
  self.dv:destroy()
end

return M
