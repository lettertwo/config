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

local Statusline = require("config.mini.statusline")

---@class ReviewApp: App
---@field open fun(kind: "uncommitted"|"stack"|"pr"|"ref", opts?: {cwd?: string, title?: string})
local ReviewApp = {
  name = "review",
}

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

  -- Configure the current buffer in place rather than creating a new one and
  -- swapping it in — the latter orphans whatever buffer was already showing
  -- (the boot-time buffer in standalone, tabnew's buffer when embedded), and
  -- neither the D7 sweep nor the embedded launch path ever reclaims it.
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_name(buf, "review://" .. kind)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "",
    "  " .. kind .. "  —  " .. cwd,
    "",
    "  (M0 scaffold — source loading arrives in M1)",
  })

  Statusline.setup_highlights()
  vim.wo[win].winbar = Statusline.make_winbar("  REVIEW  " .. title, "MiniStatuslineModeNormal")
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"

  -- q: quit in standalone (we own the process), close tab in embedded.
  vim.keymap.set("n", "q", function()
    if vim.g.app == "review" then
      _G.App.quit(0)
    else
      pcall(vim.cmd, "tabclose")
    end
  end, { buffer = buf, silent = true, desc = "Close review" })
end

function ReviewApp:run(args)
  args = args or {}
  local kind = args.kind or args[1] or vim.g.review_kind or "uncommitted"
  local cwd = args.cwd or vim.g.review_cwd or Config.root("git") or vim.fn.getcwd()
  local title = args.title or vim.g.review_title
  ReviewApp.open(kind, { cwd = cwd, title = title })
end

function ReviewApp:teardown() end

return ReviewApp
