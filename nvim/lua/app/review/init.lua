-- Review app: code-review session for uncommitted changes, stacks, PRs, and refs.
--
-- Standalone:  fish function `review` → VIM_APP=review nvim ...
-- Embedded:    :Review [kind] from any nvim session, or :App review [kind]
--
-- run(args) is called by the framework at UIEnter (standalone) or after tabnew
-- (embedded). Both paths call open(kind, opts) which builds the session in the
-- current tab — tab lifecycle is handled by the framework, not here.
--
-- Args resolution order:
--   args.kind  (embedded / :App review)
--   args[1]    (:App review uncommitted — positional from the command)
--   vim.g.review_kind  (standalone fish wrapper)
--   default "uncommitted"
--
-- M1 session state (files list, current index, save watcher) lives directly in
-- this module; a session.lua extraction point re-appears once M2/M3 add real
-- state.

local Statusline = require("config.mini.statusline")

---@class ReviewApp: App
---@field open fun(kind: "uncommitted"|"stack"|"pr"|"ref", opts?: {cwd?: string, title?: string})
local ReviewApp = {
  name = "review",
}

---@class ReviewSession
---@field kind string
---@field cwd string
---@field title string
---@field win integer
---@field dv Review.DiffView
---@field source Review.Source
---@field files Review.FileChange[]
---@field idx integer
---@field aug integer?     save-watcher augroup
---@field timer userdata?  save-watcher debounce timer

---@type ReviewSession?
local session = nil

local function stop_watcher(sess)
  if sess.timer then
    sess.timer:stop()
    sess.timer:close()
    sess.timer = nil
  end
  if sess.aug then
    pcall(vim.api.nvim_del_augroup_by_id, sess.aug)
    sess.aug = nil
  end
end

local function close_session()
  if not session then
    return
  end
  stop_watcher(session)
  session.dv:destroy()
  session = nil
end

local function set_winbar(sess)
  if not vim.api.nvim_win_is_valid(sess.win) then
    return
  end
  local text = "  REVIEW  " .. sess.title
  local file = sess.files[sess.idx]
  if file then
    text = text .. ("  %s (%d/%d)"):format(file.path, sess.idx, #sess.files)
  end
  vim.wo[sess.win].winbar = Statusline.make_winbar(text, "MiniStatuslineModeNormal")
end

-- Render the file at sess.idx. view: optional winsaveview() to restore
-- (refresh path); otherwise the cursor jumps to the first hunk.
local function show_file(sess, view)
  local file = sess.files[sess.idx]
  if not file then
    return
  end
  sess.dv:render(file, sess.cwd, function()
    if not (session == sess and vim.api.nvim_win_is_valid(sess.win)) then
      return
    end
    set_winbar(sess)
    vim.api.nvim_win_call(sess.win, function()
      if view then
        vim.fn.winrestview(view)
      else
        local hr = sess.dv.hunk_rows[1]
        if hr then
          vim.api.nvim_win_set_cursor(sess.win, { hr.first_diff + 1, 0 })
          vim.cmd("normal! zv")
        end
      end
    end)
  end)
end

local function next_file(sess)
  if sess.idx < #sess.files then
    sess.idx = sess.idx + 1
    show_file(sess)
  end
end

local function prev_file(sess)
  if sess.idx > 1 then
    sess.idx = sess.idx - 1
    show_file(sess)
  end
end

-- Jump to the first diff line of the next/prev hunk; clamps at the ends.
local function next_hunk(sess)
  local row = vim.fn.line(".") - 1
  for _, hr in ipairs(sess.dv.hunk_rows) do
    if hr.s > row then
      vim.api.nvim_win_set_cursor(sess.win, { hr.first_diff + 1, 0 })
      vim.cmd("normal! zv")
      return
    end
  end
end

local function prev_hunk(sess)
  local row = vim.fn.line(".") - 1
  local target = nil
  for _, hr in ipairs(sess.dv.hunk_rows) do
    if hr.e < row then
      target = hr
    end
  end
  if target then
    vim.api.nvim_win_set_cursor(sess.win, { target.first_diff + 1, 0 })
    vim.cmd("normal! zv")
  end
end

local function refresh(sess)
  local current_path = sess.files[sess.idx] and sess.files[sess.idx].path
  sess.source:refresh(function(changesets, err)
    if session ~= sess then
      return
    end
    if err then
      vim.notify("Review refresh error: " .. err, vim.log.levels.ERROR, { title = "Review" })
      return
    end
    sess.files = changesets and changesets[1] and changesets[1].files or {}
    if #sess.files == 0 then
      sess.idx = 1
      sess.dv:_render_placeholder("[No uncommitted changes]")
      set_winbar(sess)
      return
    end
    -- Keep the current file when it still exists; clamp the index otherwise.
    local same_file = false
    if current_path then
      for i, f in ipairs(sess.files) do
        if f.path == current_path then
          sess.idx = i
          same_file = true
          break
        end
      end
    end
    if not same_file then
      sess.idx = math.min(sess.idx, #sess.files)
    end
    local view = same_file
        and vim.api.nvim_win_is_valid(sess.win)
        and vim.api.nvim_win_call(sess.win, vim.fn.winsaveview)
      or nil
    show_file(sess, view)
  end)
end

-- Debounced refresh on file saves under the repo root and on focus regain
-- (external edits). The augroup is global, not buffer-local: writes happen in
-- other buffers (embedded mode), never in the review buffer itself.
local function start_watcher(sess)
  local cwd = vim.fs.normalize(sess.cwd)
  sess.aug = vim.api.nvim_create_augroup("ReviewSaveWatch_" .. sess.dv.bufnr, { clear = true })

  local function schedule_refresh()
    if sess.timer then
      sess.timer:stop()
      sess.timer:close()
    end
    sess.timer = vim.uv.new_timer()
    sess.timer:start(250, 0, function()
      if sess.timer then
        sess.timer:close()
        sess.timer = nil
      end
      vim.schedule(function()
        if session == sess then
          refresh(sess)
        end
      end)
    end)
  end

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = sess.aug,
    callback = function(ev)
      local path = vim.api.nvim_buf_get_name(ev.buf)
      if path == "" or vim.fs.normalize(path):sub(1, #cwd) ~= cwd then
        return
      end
      schedule_refresh()
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = sess.aug,
    callback = schedule_refresh,
  })
end

local function set_keymaps(sess)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, function()
      if session == sess then
        fn(sess)
      end
    end, { buffer = sess.dv.bufnr, silent = true, desc = desc })
  end
  map("]f", next_file, "Review: next file")
  map("[f", prev_file, "Review: previous file")
  map("]h", next_hunk, "Review: next hunk")
  map("[h", prev_hunk, "Review: previous hunk")

  -- q: quit in standalone (we own the process), close tab in embedded.
  vim.keymap.set("n", "q", function()
    if vim.g.app == "review" then
      _G.App.quit(0)
    else
      pcall(vim.cmd, "tabclose")
    end
  end, { buffer = sess.dv.bufnr, silent = true, desc = "Close review" })
end

-- Open a review session in the current tab.
--
-- Does not create a tab — the caller is responsible. In standalone mode the
-- process IS the session; in embedded mode _launch_embedded already ran tabnew.
---@param kind "uncommitted"|"stack"|"pr"|"ref"
---@param opts? { cwd?: string, title?: string }
function ReviewApp.open(kind, opts)
  opts = opts or {}
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()
  local title = opts.title or kind

  close_session()
  require("app.review.ui.signs").setup()
  Statusline.setup_highlights()

  local win = vim.api.nvim_get_current_win()

  -- The buffer currently in the window (boot-time buffer in standalone,
  -- tabnew's buffer when embedded) is orphaned once the DiffView buffer swaps
  -- in — neither the D7 sweep nor the embedded launch path reclaims it — so
  -- make sure it wipes itself.
  local init_buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(init_buf) == "" and not vim.bo[init_buf].modified then
    vim.bo[init_buf].bufhidden = "wipe"
  end

  if kind ~= "uncommitted" then
    vim.notify("Review: kind " .. kind .. " arrives in a later milestone", vim.log.levels.WARN, { title = "Review" })
    return
  end

  local dv = require("app.review.ui.diff").new({ win = win })
  -- Name the buffer so the framework's D7 unnamed-buffer sweep skips it.
  vim.api.nvim_buf_set_name(dv.bufnr, "review://" .. kind)
  local sess = {
    kind = kind,
    cwd = cwd,
    title = title,
    win = win,
    dv = dv,
    source = require("app.review.source.uncommitted").new({ cwd = cwd }),
    files = {},
    idx = 1,
  }
  session = sess
  set_keymaps(sess)
  dv:_render_placeholder("Loading " .. title .. "  —  " .. cwd .. " …")
  set_winbar(sess)

  sess.source:load(function(changesets, err)
    if session ~= sess then
      return
    end
    if err then
      dv:_render_placeholder("[Review error: " .. err .. "]")
      return
    end
    sess.files = changesets and changesets[1] and changesets[1].files or {}
    if #sess.files == 0 then
      dv:_render_placeholder("[No uncommitted changes]")
      return
    end
    show_file(sess)
    start_watcher(sess)
  end)
end

function ReviewApp:run(args)
  args = args or {}
  local kind = args.kind or args[1] or vim.g.review_kind or "uncommitted"
  local cwd = args.cwd or vim.g.review_cwd or Config.root("git") or vim.fn.getcwd()
  local title = args.title or vim.g.review_title
  ReviewApp.open(kind, { cwd = cwd, title = title })
end

function ReviewApp:teardown()
  close_session()
end

return ReviewApp
