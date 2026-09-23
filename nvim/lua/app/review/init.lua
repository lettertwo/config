-- Review app: code review for uncommitted changes, stacks, PRs, and refs.
--
-- Standalone:  fish function `review` → VIM_APP=review nvim ...
-- Embedded:    :Review [source] from any nvim session, or :App review [source]
--
-- run(args) is called by the framework at UIEnter (standalone) or after tabnew
-- (embedded). It classifies the one source argument, then, unless
-- classification names a failure, calls open(classified, opts) to build the
-- docket in the current tab — tab lifecycle is handled by the framework, not
-- here.
--
-- Source argument resolution order:
--   args.source  (embedded / :App review)
--   args[1]      (:App review main..feature — positional from the command)
--   vim.g.review_source
--   $REVIEW_SOURCE  (standalone fish wrapper; env var for the same quoting
--                    reasons as VIM_APP)
--   default ""  (classifies as "stack")

local Statusline = require("config.mini.statusline")
local nav_keymaps = require("app.review.keymaps")
local classify = require("app.review.source.classify")

---@class ReviewApp: App
---@field open fun(classified: table, opts?: {cwd?: string, title?: string})
local ReviewApp = {
  name = "review",
}

---@type Review.Docket?
local docket = nil

local function close_docket()
  if docket then
    docket:destroy()
    docket = nil
  end
end

-- Close the review: quit in standalone (we own the process), close the tab
-- in embedded. Used by the diff-buffer q keymap, the outline's q/<Esc>, and
-- a named classification/resolution failure (exit code 1, no fallback).
local function close_review(code)
  if vim.g.app == "review" then
    _G.App.quit(code or 0)
  else
    pcall(vim.cmd, "tabclose")
  end
end

-- A named failure closes the review outright rather than falling back to
-- another source.
local function fail(reason)
  vim.notify("Review: " .. reason, vim.log.levels.ERROR, { title = "Review" })
  close_review(1)
end

local function set_keymaps(dk)
  -- Every pane buffer of both rows gets the maps. Cursor-based nav refocuses
  -- the pressed row's primary window (its left pane follows via scrollbind);
  -- staging ops stay put — the pane under the cursor IS their target.
  for _, dv in ipairs({ dk.dv, dk.dv2 }) do
    for _, bufnr in ipairs({ dv.right.bufnr, dv.left.bufnr }) do
      local function map(lhs, method, desc, refocus)
        vim.keymap.set("n", lhs, function()
          if dk._closed then
            return
          end
          if refocus and dv.right:win_valid() and vim.api.nvim_get_current_win() ~= dv.right.win then
            vim.api.nvim_set_current_win(dv.right.win)
          end
          dk[method](dk)
        end, { buffer = bufnr, silent = true, desc = desc })
      end
      for _, nav in ipairs(nav_keymaps) do
        map(nav.lhs, nav.method, nav.desc, true)
      end
      map("<leader>rl", "toggle_layout", "Review: toggle side-by-side")
      map("<leader>rz", "cycle_zoom", "Review: cycle zoom")
      map("<leader>rs", "stage_current", "Review: toggle-stage hunk")
      map("<leader>rS", "stage_current_file", "Review: toggle-stage file")
      map("<leader>rd", "discard_current", "Review: discard hunk")
      map("<leader>rD", "discard_current_file", "Review: discard file")

      -- Visual-mode variants: line-precise staging over the selected rows.
      -- The live range is read from the active selection ('<,'> marks are
      -- stale until visual exits), then visual is left SYNCHRONOUSLY —
      -- discard's vim.fn.confirm reads input, so a queued <Esc> via
      -- feedkeys would be eaten as a dialog abort.
      local function vmap(lhs, method, desc)
        vim.keymap.set("x", lhs, function()
          if dk._closed then
            return
          end
          local lo = vim.fn.getpos("v")[2]
          local hi = vim.fn.line(".")
          if lo > hi then
            lo, hi = hi, lo
          end
          vim.cmd("normal! \27")
          dk[method](dk, lo, hi)
        end, { buffer = bufnr, silent = true, desc = desc })
      end
      vmap("<leader>rs", "stage_selection", "Review: toggle-stage selected lines")
      vmap("<leader>rd", "discard_selection", "Review: discard selected lines")

      vim.keymap.set("n", "<leader>o", function()
        if not dk._closed and dk.outline then
          dk.outline:open()
        end
      end, { buffer = bufnr, silent = true, desc = "Review: focus outline" })

      vim.keymap.set("n", "q", function()
        -- An outline peek float can still be open (visible, unfocused) if
        -- focus moved to a diff pane without dismissing it first — q here
        -- should close it rather than closing the whole review.
        if require("app.review.ui.peek").close() then
          return
        end
        close_review()
      end, { buffer = bufnr, silent = true, desc = "Close review" })
    end
  end
end

-- Create the outline sidebar for a docket. Snacks comes from the app's own
-- plugins/snacks.lua (standalone) or the host app (embedded); a missing
-- picker degrades to a diff-only review rather than an error.
local function open_outline(dk)
  if not (pcall(require, "snacks") and _G.Snacks and Snacks.picker) then
    vim.notify("Review: snacks.picker unavailable — outline disabled", vim.log.levels.WARN, { title = "Review" })
    return
  end
  dk.outline = require("app.review.ui.outline").new({
    docket = dk,
    on_select = function(item)
      -- Non-file rows have no diff of their own: <CR> enters the group at
      -- its first file (quickfix-style), same as clicking a file directly.
      local change = item.change
      if not change and item.type == "changeset" then
        change = item.changeset.files[1]
      elseif not change and item.type == "dir" then
        for _, f in ipairs(dk.files) do
          if f.path:sub(1, #item.path + 1) == item.path .. "/" then
            change = f
            break
          end
        end
      end
      if change then
        dk:focus_file(change)
        if vim.api.nvim_win_is_valid(dk.win) then
          vim.api.nvim_set_current_win(dk.win)
        end
      end
    end,
    on_close = close_review,
  })
end

-- The window title and source-module constructor opts for a classified
-- source. Only the "ref" module needs the classified table itself — stack
-- and uncommitted take no source-specific opts.
---@param classified table
---@return string title, table source_opts
local function dispatch(classified, cwd)
  if classified.kind == "ref" then
    if classified.shape == "range" then
      local sep = classified.dots == 3 and "..." or ".."
      return classified.base .. sep .. classified.head, { cwd = cwd, classified = classified }
    end
    return classified.ref, { cwd = cwd, classified = classified }
  end
  return classified.kind, { cwd = cwd }
end

-- Open a review docket in the current tab.
--
-- Does not create a tab — the caller is responsible. In standalone mode the
-- process IS the review; in embedded mode _launch_embedded already ran tabnew.
---@param classified table  source/classify.lua's result
---@param opts? { cwd?: string, title?: string }
function ReviewApp.open(classified, opts)
  opts = opts or {}
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()
  local default_title, source_opts = dispatch(classified, cwd)
  local title = opts.title or default_title
  local kind = classified.kind

  close_docket()
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

  local dv = require("app.review.ui.diff").new({ win = win })
  -- The staged-row DiffView; its window arrives with the split zoom.
  local dv2 = require("app.review.ui.diff").new({ win = -1 })
  -- Name the buffers so the framework's D7 unnamed-buffer sweep skips them.
  vim.api.nvim_buf_set_name(dv.right.bufnr, "review://" .. kind)
  vim.api.nvim_buf_set_name(dv.left.bufnr, "review://" .. kind .. "//old")
  vim.api.nvim_buf_set_name(dv2.right.bufnr, "review://" .. kind .. "//staged")
  vim.api.nvim_buf_set_name(dv2.left.bufnr, "review://" .. kind .. "//staged//old")

  docket = require("app.review.docket").new({
    kind = kind,
    cwd = cwd,
    title = title,
    win = win,
    dv = dv,
    dv2 = dv2,
    source = require("app.review.source." .. kind).new(source_opts),
  })
  set_keymaps(docket)
  dv:_render_placeholder("Loading " .. title .. "  —  " .. cwd .. " …")
  docket:set_winbar()
  open_outline(docket)
  docket:load()
end

function ReviewApp:run(args)
  args = args or {}
  local text = args.source or args[1] or vim.g.review_source or vim.env.REVIEW_SOURCE or ""
  local cwd = args.cwd or vim.g.review_cwd or Config.root("git") or vim.fn.getcwd()
  local title = args.title or vim.g.review_title

  local classified, err = classify.classify(text)
  if not classified then
    fail(err)
    return
  end
  -- The pr arm classifies here; resolving it against gh lands separately.
  if classified.kind == "pr" then
    fail("PR review is not implemented yet")
    return
  end

  ReviewApp.open(classified, { cwd = cwd, title = title })
end

function ReviewApp:teardown()
  close_docket()
end

-- The active docket, if any. For tests and debugging.
function ReviewApp._active_docket()
  return docket
end

return ReviewApp
