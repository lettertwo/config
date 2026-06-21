-- Scrollback app: lean read-only ANSI pager invoked by kitty as scrollback_pager.
--
-- Kitty invokes nvim via kitty.conf:
--   scrollback_pager nvim \
--     --cmd 'let g:app="scrollback"' \
--     --cmd 'let g:scrollback_input_line=INPUT_LINE_NUMBER' \
--     --cmd 'let g:scrollback_cursor_line=CURSOR_LINE' \
--     --cmd 'let g:scrollback_cursor_col=CURSOR_COLUMN' \
--     +'file! kitty-scrollback' \
--     -
--
-- Keybindings in kitty/keybind.conf:
--   map cmd+s show_scrollback           → full scrollback (cursor_line > 0)
--   map cmd+g show_last_command_output  → last cmd output (cursor_line == 0)
--
-- ANSI rendering: run() calls nvim_open_term(buf, {}) directly. TermOpen fires
-- synchronously within that call; the settle loop starts there, polling every
-- 50 ms until the PTY flush stabilises, then jumps to the target line.
-- +'file! kitty-scrollback' names the buffer so the framework's D7 cleanup
-- (which wipes unnamed buffers at UIEnter) skips it.
--
-- Mode detection (both maps share one scrollback_pager):
--   full scrollback    → cursor_line > 0; jump to INPUT_LINE_NUMBER (screen top)
--   last cmd output    → cursor_line == 0 && cursor_col == 0; jump to top

local Statusline = require("config.mini.statusline")

---@type App
---@diagnostic disable-next-line: missing-fields
local ScrollbackApp = {
  name = "scrollback",
}

function ScrollbackApp:run()
  local cursor_line = tonumber(vim.g.scrollback_cursor_line) or 0
  local cursor_col = tonumber(vim.g.scrollback_cursor_col) or 0

  -- cursor_line/col == 0 means kitty has no cursor (show_last_command_output).
  local is_last_cmd = cursor_line == 0 and cursor_col == 0

  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  local function jump()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local line_count = vim.api.nvim_buf_line_count(buf)
    if line_count == 0 then
      return
    end
    if vim.fn.mode() ~= "n" then
      vim.cmd("stopinsert")
    end
    -- The nvim terminal buffer has extra blank rows at the end (the terminal
    -- viewport area after content). Scan backward to find the last non-empty
    -- line — that's where the prompt is. At most ~terminal_height iterations.
    local target = line_count
    for i = line_count, 1, -1 do
      local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
      if line and line ~= "" then
        target = i
        break
      end
    end
    pcall(vim.api.nvim_win_set_cursor, win, { target, 0 })
    vim.cmd("normal! zb")
  end

  -- Open the terminal channel on the populated stdin buffer. The buffer's
  -- existing lines (ANSI-coded scrollback) are fed through the PTY, which
  -- renders escape codes as real colors. nvim 0.12+ required.
  -- Note: nvim_open_term is headless (no job), so TermOpen never fires —
  -- we start the settle loop directly after the call instead.
  vim.api.nvim_open_term(buf, {})

  -- Poll until the PTY flush settles, then jump to the last line.
  -- TermEnter is not used because nvim_open_term doesn't trigger it either;
  -- we call stopinsert explicitly in jump() instead.
  local attempts, prev_count, stable = 0, -1, 0
  local timer = vim.uv.new_timer()
  if timer then
    timer:start(
      50,
      50,
      vim.schedule_wrap(function()
        if not vim.api.nvim_buf_is_valid(buf) then
          timer:stop()
          timer:close()
          return
        end
        local count = vim.api.nvim_buf_line_count(buf)
        if count > 0 and count == prev_count then
          stable = stable + 1
        else
          stable = 0
        end
        prev_count = count
        attempts = attempts + 1
        if stable >= 2 or attempts >= 40 then
          timer:stop()
          timer:close()
          jump()
        end
      end)
    )
  end

  -- Window options — clean read-only view.
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].list = false
  vim.wo[win].scrolloff = 0

  -- Winbar: mode-color pill + powerline separator via shared make_winbar.
  Statusline.setup_highlights()
  local label = is_last_cmd and " 󰄛 LAST COMMAND OUTPUT" or " 󰄛 SCROLLBACK"
  vim.wo[win].winbar = Statusline.make_winbar(label, "MiniStatuslineModeNormal")

  -- Buffer-local keymap (normal mode; terminal mode is suppressed above).
  vim.keymap.set("n", "q", function()
    _G.App.quit(0)
  end, {
    buffer = buf,
    silent = true,
    desc = "Quit scrollback",
  })
end

function ScrollbackApp:teardown() end

return ScrollbackApp
