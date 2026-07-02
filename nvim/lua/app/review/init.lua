-- Review app: code review for uncommitted changes, stacks, PRs, and refs.
--
-- Standalone:  fish function `review` → VIM_APP=review nvim ...
-- Embedded:    :Review [kind] from any nvim session, or :App review [kind]
--
-- run(args) is called by the framework at UIEnter (standalone) or after tabnew
-- (embedded). Both paths call open(kind, opts) which builds the docket in the
-- current tab — tab lifecycle is handled by the framework, not here.
--
-- Args resolution order:
--   args.kind  (embedded / :App review)
--   args[1]    (:App review uncommitted — positional from the command)
--   vim.g.review_kind
--   $REVIEW_KIND  (standalone fish wrapper; env var for the same quoting
--                  reasons as VIM_APP)
--   default "uncommitted"

local Statusline = require("config.mini.statusline")

---@class ReviewApp: App
---@field open fun(kind: "uncommitted"|"stack"|"pr"|"ref", opts?: {cwd?: string, title?: string})
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

local function set_keymaps(dk)
  local function map(lhs, method, desc)
    vim.keymap.set("n", lhs, function()
      if not dk._closed then
        dk[method](dk)
      end
    end, { buffer = dk.dv.bufnr, silent = true, desc = desc })
  end
  map("]f", "next_file", "Review: next file")
  map("[f", "prev_file", "Review: previous file")
  map("]h", "next_hunk", "Review: next hunk")
  map("[h", "prev_hunk", "Review: previous hunk")
  map("]c", "next_changeset", "Review: next changeset")
  map("[c", "prev_changeset", "Review: previous changeset")

  -- q: quit in standalone (we own the process), close tab in embedded.
  vim.keymap.set("n", "q", function()
    if vim.g.app == "review" then
      _G.App.quit(0)
    else
      pcall(vim.cmd, "tabclose")
    end
  end, { buffer = dk.dv.bufnr, silent = true, desc = "Close review" })
end

-- Open a review docket in the current tab.
--
-- Does not create a tab — the caller is responsible. In standalone mode the
-- process IS the review; in embedded mode _launch_embedded already ran tabnew.
---@param kind "uncommitted"|"stack"|"pr"|"ref"
---@param opts? { cwd?: string, title?: string }
function ReviewApp.open(kind, opts)
  opts = opts or {}
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()
  local title = opts.title or kind

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

  local KINDS = { uncommitted = true, stack = true }
  if not KINDS[kind] then
    vim.notify("Review: kind " .. kind .. " arrives in a later milestone", vim.log.levels.WARN, { title = "Review" })
    return
  end

  local dv = require("app.review.ui.diff").new({ win = win })
  -- Name the buffer so the framework's D7 unnamed-buffer sweep skips it.
  vim.api.nvim_buf_set_name(dv.bufnr, "review://" .. kind)

  docket = require("app.review.docket").new({
    kind = kind,
    cwd = cwd,
    title = title,
    win = win,
    dv = dv,
    source = require("app.review.source." .. kind).new({ cwd = cwd }),
  })
  set_keymaps(docket)
  dv:_render_placeholder("Loading " .. title .. "  —  " .. cwd .. " …")
  docket:set_winbar()
  docket:load()
end

function ReviewApp:run(args)
  args = args or {}
  local kind = args.kind or args[1] or vim.g.review_kind or vim.env.REVIEW_KIND or "uncommitted"
  local cwd = args.cwd or vim.g.review_cwd or Config.root("git") or vim.fn.getcwd()
  local title = args.title or vim.g.review_title
  ReviewApp.open(kind, { cwd = cwd, title = title })
end

function ReviewApp:teardown()
  close_docket()
end

return ReviewApp
