-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Show relative line numbers in visual and operator-pending modes.
-- HACK: ModeChanged doesn't fire consistently when pending a motion,
-- so, we bind directly to keys that enter visual and operator-pending mode.
vim.on_key(function(char)
  if char:match("^[cdyvV\x16]$") then
    vim.opt_local.relativenumber = true
  end
end)

vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = { "*[ovV\x16]*:*" },
  callback = function()
    vim.opt_local.relativenumber = false
  end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    vim.opt_local.relativenumber = false
  end,
})

vim.api.nvim_create_autocmd({ "BufReadPre", "BufEnter" }, {
  callback = function()
    vim.schedule(function()
      vim.opt_local.relativenumber = false
    end)
  end,
})

-- Close cmdwin with <Esc>
vim.api.nvim_create_autocmd("CmdwinEnter", {
  callback = function()
    vim.keymap.set("n", "<Esc>", "<C-c><C-c>", { buffer = 0 })
  end,
})

vim.api.nvim_create_autocmd("Filetype", {
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove("t") -- Disable text wrapping
    vim.opt_local.formatoptions:remove("o") -- Disable comment continuation when entering insert mode
  end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("lazyvim_close_with_q", { clear = true }),
  pattern = LazyVim.config.filetypes.ui,
  callback = function(event)
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
  end,
})

if os.getenv("KITTY_WINDOW_ID") then
  local kitty_set_spacing = vim.api.nvim_create_augroup("kitty_set_spacing", { clear = true })

  -- Set the padding and margin of the kitty window when entering nvim
  if vim.v.vim_did_enter == 1 then
    vim.system({ "kitty", "@set-spacing", "padding=0", "margin=0" })
  else
    vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
      group = kitty_set_spacing,
      pattern = "*",
      callback = function()
        vim.system({ "kitty", "@set-spacing", "padding=0", "margin=0" })
      end,
    })
  end

  -- Reset the spacing of the kitty window when leaving nvim
  vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
    group = kitty_set_spacing,
    pattern = "*",
    callback = function()
      vim.system({ "kitty", "@set-spacing", "padding=default", "margin=default" })
    end,
  })
end
