-- Check if we need to reload the file when it changed
Config.on({ "FocusGained", "TermClose", "TermLeave" }, function()
  if vim.o.buftype ~= "nofile" then
    vim.cmd("checktime")
  end
end)

-- Toggle cursor line in active window
Config.on({ "WinEnter", "WinLeave", "FocusGained", "FocusLost" }, function(e)
  vim.wo.cursorline = e.event == "WinEnter" or e.event == "FocusGained"
end)

-- Highlight on yank
Config.on("TextYankPost", function()
  (vim.hl or vim.highlight).on_yank()
end)

-- resize splits if window got resized
Config.on("VimResized", function()
  local current_tab = vim.fn.tabpagenr()
  vim.cmd("tabdo wincmd =")
  vim.cmd("tabnext " .. current_tab)
end)

-- go to last loc when opening a buffer
Config.on("BufReadPost", function(event)
  local exclude = { "gitcommit" }
  local buf = event.buf
  if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
    return
  end
  vim.b[buf].lazyvim_last_loc = true
  local mark = vim.api.nvim_buf_get_mark(buf, '"')
  local lcount = vim.api.nvim_buf_line_count(buf)
  if mark[1] > 0 and mark[1] <= lcount then
    pcall(vim.api.nvim_win_set_cursor, 0, mark)
  end
end)

-- Auto create dir when saving a file, in case some intermediate directory does not exist
Config.on("BufWritePre", function(event)
  if event.match:match("^%w%w+:[\\/][\\/]") then
    return
  end
  local file = vim.uv.fs_realpath(event.match) or event.match
  vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
end)

-- Close cmdwin with <Esc>
Config.on("CmdwinEnter", function()
  vim.keymap.set("n", "<Esc>", "<C-c><C-c>", { buffer = 0 })
end)

Config.on("Filetype", function()
  vim.opt_local.formatoptions:remove("c") -- Disable comment wrapping
  vim.opt_local.formatoptions:remove("o") -- Disable comment continuation when entering insert mode
end)

-- close some filetypes with <q>
Config.on("FileType", function(event)
  vim.bo[event.buf].buflisted = false
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(event.buf) then
      return
    end
    -- first check if buffer already has a mapping for q
    local existing_mapping = vim.api.nvim_buf_get_keymap(event.buf, "n")
    for _, map in ipairs(existing_mapping) do
      if map.lhs == "q" then
        return
      end
    end
    vim.keymap.set("n", "q", function()
      vim.cmd("close")
      pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
    end, {
      buffer = event.buf,
      silent = true,
      desc = "Quit buffer",
    })
  end)
end)

-- Enable relative line numbers and disable inlay hints when:
--   - entering visual (char|line|block) mode
--   - entering operator-pending mode
Config.on("ModeChanged", "*:*[ovV\x16]*", function()
  vim.opt_local.relativenumber = true
  vim.lsp.inlay_hint.enable(false, { bufnr = 0 })
end)

-- Disable relative line numbers and enable inlay hints when:
--   - leaving visual (char|line|block) mode
--   - leaving operator-pending mode
Config.on("ModeChanged", "*[ovV\x16]*:*", function()
  vim.opt_local.relativenumber = false
  vim.lsp.inlay_hint.enable(true, { bufnr = 0 })
end)

-- Disable relative line numbers and enable inlay hints when leaving insert mode
Config.on("InsertLeave", function()
  vim.opt_local.relativenumber = false
  vim.lsp.inlay_hint.enable(true, { bufnr = 0 })
end)

-- Disable relative line numbers and inlay hints when entering insert mode
Config.on("InsertEnter", function()
  vim.opt_local.relativenumber = false
  vim.lsp.inlay_hint.enable(false, { bufnr = 0 })
end)

if os.getenv("KITTY_WINDOW_ID") then
  -- Set the padding and margin of the kitty window when entering nvim
  if vim.v.vim_did_enter == 1 then
    vim.system({ "kitty", "@set-spacing", "padding=0", "margin=0" })
  else
    Config.on({ "VimEnter", "VimResume" }, "*", function()
      vim.system({ "kitty", "@set-spacing", "padding=0", "margin=0" })
    end)
  end

  -- Reset the spacing of the kitty window when leaving nvim
  Config.on({ "VimLeave", "VimSuspend" }, "*", function()
    vim.system({ "kitty", "@set-spacing", "padding=default", "margin=default" })
  end)
end
