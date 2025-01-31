-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Show relative line numbers in visual modes
-- FIXME: ModeChanged doesn't fire when visual mode is pending a motion,
-- but does fire after visual mode is exited, even if no motion was specified.
-- We need a way to flip the relative number bit when visual mode is pending.
-- Ideally, we'd do so for any pending operator?
-- vim.api.nvim_create_autocmd("ModeChanged", {
--   pattern = { "*:*" },
--   callback = function(e)
--     vim.notify("Mode changed to " .. e.match, "debug")
--   end,
-- })
vim.api.nvim_create_autocmd("ModeChanged", { pattern = { "[vV\x16]*:*" }, command = ":setlocal norelativenumber" })
vim.api.nvim_create_autocmd("ModeChanged", { pattern = { "*:[vV\x16]*" }, command = ":setlocal relativenumber" })

-- -- stylua: ignore
-- Mode.map = {
--   ['n']      = 'NORMAL',
--   ['no']     = 'O-PENDING',
--   ['nov']    = 'O-PENDING',
--   ['noV']    = 'O-PENDING',
--   ['no\22'] = 'O-PENDING',
--   ['niI']    = 'NORMAL',
--   ['niR']    = 'NORMAL',
--   ['niV']    = 'NORMAL',
--   ['nt']     = 'NORMAL',
--   ['ntT']    = 'NORMAL',
--   ['v']      = 'VISUAL',
--   ['vs']     = 'VISUAL',
--   ['V']      = 'V-LINE',
--   ['Vs']     = 'V-LINE',
--   ['\22']   = 'V-BLOCK',
--   ['\22s']  = 'V-BLOCK',
--   ['s']      = 'SELECT',
--   ['S']      = 'S-LINE',
--   ['\19']   = 'S-BLOCK',
--   ['i']      = 'INSERT',
--   ['ic']     = 'INSERT',
--   ['ix']     = 'INSERT',
--   ['R']      = 'REPLACE',
--   ['Rc']     = 'REPLACE',
--   ['Rx']     = 'REPLACE',
--   ['Rv']     = 'V-REPLACE',
--   ['Rvc']    = 'V-REPLACE',
--   ['Rvx']    = 'V-REPLACE',
--   ['c']      = 'COMMAND',
--   ['cv']     = 'EX',
--   ['ce']     = 'EX',
--   ['r']      = 'REPLACE',
--   ['rm']     = 'MORE',
--   ['r?']     = 'CONFIRM',
--   ['!']      = 'SHELL',
--   ['t']      = 'TERMINAL',
-- }
--
-- ---@return string current mode name
-- function Mode.get_mode()
--   local mode_code = vim.api.nvim_get_mode().mode
--   if Mode.map[mode_code] == nil then
--     return mode_code
--   end
--   return Mode.map[mode_code]
-- end

vim.api.nvim_create_autocmd({
  "InsertEnter",
}, {
  callback = function()
    vim.opt_local.relativenumber = false
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
  pattern = require("lazyvim.config").filetypes.ui,
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(event.buf) then
        return
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
