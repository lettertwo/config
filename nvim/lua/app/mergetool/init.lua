-- Mergetool app: standalone 3-pane conflict resolution (LOCAL | MERGED | REMOTE).
--
-- Git invokes nvim via:
--   [mergetool "nvim-app"]
--   cmd = VIM_APP=mergetool nvim -d -i NONE $LOCAL $MERGED $REMOTE
--   trustExitCode = true
--
-- -d opens the three files in diff-mode splits with splitright, so each new
-- split goes RIGHT, producing the correct LOCAL | MERGED | REMOTE layout.
-- BASE is omitted — zdiff3 conflict style embeds base context in the markers.
--
-- argv order: LOCAL=0, MERGED=1, REMOTE=2
--
-- Exit contract (D5):
--   complete → write MERGED + App.quit(0)    (git marks conflict resolved)
--   abort    → App.quit(1)                   (git leaves conflict unresolved)

---@type App
---@diagnostic disable-next-line: missing-fields
local MergetoolApp = {
  name = "mergetool",
}

local map = vim.keymap.set
local Statusline = require("config.mini.statusline")

---@return { local_: string, merged: string, remote: string, base: string }|nil, string?
local function parse_args()
  local argc = vim.fn.argc()
  if argc < 3 then
    return nil, string.format("mergetool requires 3 args, got %d", argc)
  end
  return {
    local_ = vim.fn.argv(0) --[[@as string]],
    merged = vim.fn.argv(1) --[[@as string]],
    remote = vim.fn.argv(2) --[[@as string]],
  }
end

-- Return the window currently showing bufnr, or nil.
local function win_for(bufnr)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
end

function MergetoolApp:run()
  local files, err = parse_args()
  if not files then
    vim.notify("[mergetool] " .. (err or "unknown error"), vim.log.levels.ERROR)
    _G.App.quit(1)
    return
  end

  -- -d has already opened LOCAL, MERGED, REMOTE in splits with diff mode.
  local local_buf = vim.fn.bufnr(files.local_)
  local merged_buf = vim.fn.bufnr(files.merged)
  local remote_buf = vim.fn.bufnr(files.remote)

  -- noswapfile on all three; readonly on LOCAL and REMOTE.
  for _, buf in ipairs({ local_buf, merged_buf, remote_buf }) do
    vim.bo[buf].swapfile = false
  end
  for _, buf in ipairs({ local_buf, remote_buf }) do
    vim.bo[buf].readonly = true
    vim.bo[buf].modifiable = false
  end

  Statusline.setup_highlights()

  local winbar_cfg = {
    [local_buf] = { label = " LOCAL", hl = "MiniStatuslineModeInsert" },
    [merged_buf] = { label = " MERGED", hl = "MiniStatuslineModeNormal" },
    [remote_buf] = { label = " REMOTE", hl = "MiniStatuslineModeCommand" },
  }
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local cfg = winbar_cfg[buf]
    if cfg then
      vim.wo[win].winbar = Statusline.make_winbar(cfg.label, cfg.hl)
    end
  end

  -- Focus MERGED (cursor starts in REMOTE after -d setup).
  local merged_win = win_for(merged_buf)
  if merged_win then
    vim.api.nvim_set_current_win(merged_win)
  end

  -- Exit handler: the single decision point for success vs abort.
  -- On any exit with code 0 (<leader>qq / :qa / last-window-close):
  --   no conflict markers → write MERGED and exit 0 (git: resolved)
  --   markers remain      → cquit 1               (git: unresolved)
  -- On forced non-zero exit (<leader>qQ / :cq!) → skip and let it pass through.
  -- NOTE: os.exit() is intentionally avoided here — it bypasses nvim's terminal
  -- cleanup (rmcup), leaving artifacts in the scrollback. cquit lets nvim restore
  -- the terminal properly before handing control back to git. The `once = true`
  -- on this autocmd ensures cquit doesn't re-trigger it.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    once = true,
    group = vim.api.nvim_create_augroup("MergetoolExit", { clear = true }),
    callback = function()
      -- Read the live buffer (includes unsaved undo state).
      -- If reading fails for any reason, abort to be safe.
      local ok, lines = pcall(vim.api.nvim_buf_get_lines, merged_buf, 0, -1, false)
      if not ok then
        vim.cmd("cquit 1")
        return
      end

      for _, line in ipairs(lines) do
        -- Check both opening and closing markers: a sloppy manual edit might
        -- remove <<<<<<< but leave >>>>>>> (or vice versa) still in the file.
        -- Skip ======= — it appears legitimately in Markdown horizontal rules etc.
        if line:match("^<<<<<<<") or line:match("^>>>>>>>") then
          vim.cmd("cquit 1") -- unresolved — abort regardless of how nvim was told to exit
          return
        end
      end

      -- No markers: write MERGED if modified, then let nvim exit with its own
      -- code (0 for :qa, 1 for :cq! — both handled correctly without us
      -- needing to inspect vim.v.exitcode, which is unreliable here).
      if vim.api.nvim_buf_is_valid(merged_buf) and vim.bo[merged_buf].modified then
        pcall(vim.api.nvim_buf_call, merged_buf, function()
          vim.cmd("write")
        end)
      end
    end,
  })

  -- ---- Navigation + editing keymaps ----
  local all_bufs = { local_buf, merged_buf, remote_buf }

  -- Jump to next/prev conflict marker in MERGED, focusing that window.
  -- Works from any pane; scrollbind keeps LOCAL/REMOTE in sync automatically.
  local function goto_conflict(dir)
    local mw = win_for(merged_buf)
    if not mw then
      return
    end
    local cur = vim.api.nvim_win_get_cursor(mw)[1]
    local lines = vim.api.nvim_buf_get_lines(merged_buf, 0, -1, false)
    local n = #lines

    local function search(from, to, step)
      for i = from, to, step do
        if lines[i]:match("^<<<<<<<") then
          vim.api.nvim_set_current_win(mw)
          vim.api.nvim_win_set_cursor(mw, { i, 0 })
          return true
        end
      end
    end

    if dir == "next" then
      if not search(cur + 1, n, 1) then
        search(1, cur, 1)
      end
    else
      if not search(cur - 1, 1, -1) then
        search(n, cur, -1)
      end
    end
  end

  for _, buf in ipairs(all_bufs) do
    local o = { buffer = buf, silent = true }
    map("n", "<leader>mn", function()
      goto_conflict("next")
    end, vim.tbl_extend("force", o, { desc = "Next conflict" }))
    map("n", "<leader>mp", function()
      goto_conflict("prev")
    end, vim.tbl_extend("force", o, { desc = "Prev conflict" }))
    map("n", "<leader>mj", function()
      vim.cmd("normal! ]c")
    end, vim.tbl_extend("force", o, { desc = "Next hunk" }))
    map("n", "<leader>mk", function()
      vim.cmd("normal! [c")
    end, vim.tbl_extend("force", o, { desc = "Prev hunk" }))
    map("n", "<leader>mu", "<cmd>diffupdate<cr>", vim.tbl_extend("force", o, { desc = "Update diff" }))
    map("n", "<leader>m<space>", function()
      require("which-key").show({ keys = "<leader>m", loop = true })
    end, vim.tbl_extend("force", o, { desc = "Mergetool mode" }))
  end

  -- Get-hunk / combine actions — only apply when editing MERGED.
  local mo = { buffer = merged_buf, silent = true }

  -- Parse the conflict block containing cursor_line (1-indexed).
  -- Returns { start_l, sep_l, end_l, ours, theirs } or nil on failure.
  local function parse_conflict(cursor_line)
    local lines = vim.api.nvim_buf_get_lines(merged_buf, 0, -1, false)

    local start_l
    for i = cursor_line, 1, -1 do
      if lines[i]:match("^<<<<<<<") then
        start_l = i
        break
      end
    end
    if not start_l then
      vim.notify("[mergetool] no conflict block at cursor", vim.log.levels.WARN)
      return
    end

    -- Search forward for ||||||| (zdiff3 base marker), =======, >>>>>>>
    local base_l, sep_l, end_l
    for i = start_l, #lines do
      if lines[i]:match("^|||||||") then
        base_l = i
      elseif lines[i]:match("^=======") then
        sep_l = i
      elseif lines[i]:match("^>>>>>>>") then
        end_l = i
        break
      end
    end
    if not sep_l or not end_l then
      vim.notify("[mergetool] malformed conflict block", vim.log.levels.WARN)
      return
    end

    -- ours  = lines between <<<< and |||| (zdiff3) or <<<< and ==== (plain)
    -- theirs = lines between ==== and >>>>
    local ours_end = (base_l or sep_l) - 1
    local ours, theirs = {}, {}
    for i = start_l + 1, ours_end do
      ours[#ours + 1] = lines[i]
    end
    for i = sep_l + 1, end_l - 1 do
      theirs[#theirs + 1] = lines[i]
    end

    return { start_l = start_l, end_l = end_l, ours = ours, theirs = theirs }
  end

  local function resolve_conflict(side)
    local mw = win_for(merged_buf)
    if not mw then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(mw)[1]
    local block = parse_conflict(cursor)
    if not block then
      return
    end
    local replacement = side == "ours" and block.ours or block.theirs
    -- nvim_buf_set_lines uses 0-indexed rows, end is exclusive
    vim.api.nvim_buf_set_lines(merged_buf, block.start_l - 1, block.end_l, false, replacement)
  end

  map("n", "<leader>mo", function()
    resolve_conflict("ours")
  end, vim.tbl_extend("force", mo, { desc = "Ours (get from LOCAL)" }))
  map("n", "<leader>mt", function()
    resolve_conflict("theirs")
  end, vim.tbl_extend("force", mo, { desc = "Theirs (get from REMOTE)" }))
  map("n", "<leader>mh", function()
    resolve_conflict("ours")
  end, vim.tbl_extend("force", mo, { desc = "← LOCAL" }))
  map("n", "<leader>ml", function()
    resolve_conflict("theirs")
  end, vim.tbl_extend("force", mo, { desc = "→ REMOTE" }))

  -- "Both": keep ours then theirs by parsing the conflict block under the cursor.
  -- Handles zdiff3 format (<<<< / ||||| / ==== / >>>>).
  map("n", "<leader>mb", function()
    local mw = win_for(merged_buf)
    if not mw then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(mw)[1]
    local block = parse_conflict(cursor)
    if not block then
      return
    end
    local replacement = vim.list_extend(vim.deepcopy(block.ours), block.theirs)
    vim.api.nvim_buf_set_lines(merged_buf, block.start_l - 1, block.end_l, false, replacement)
  end, vim.tbl_extend("force", mo, { desc = "Both (ours then theirs)" }))

  -- Register <leader>m as a named group buffer-locally so the loop popup has a
  -- title. Deferred because which-key.nvim is added to runtimepath via
  -- vim.schedule in plugin/which-key.lua, so it isn't require()-able at UIEnter.
  vim.schedule(function()
    local ok, wk = pcall(require, "which-key")
    if not ok then
      return
    end
    wk.add({
      { "<leader>m", group = "mergetool", buffer = local_buf },
      { "<leader>m", group = "mergetool", buffer = merged_buf },
      { "<leader>m", group = "mergetool", buffer = remote_buf },
    })
  end)

  vim.notify(
    "[mergetool] <leader>m<space> — mergetool mode · quit when done (<leader>qq) · force abort (<leader>qQ)",
    vim.log.levels.INFO
  )
end

function MergetoolApp:teardown() end

return MergetoolApp
