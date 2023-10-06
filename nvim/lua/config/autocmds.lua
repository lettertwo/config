-- Adapted from: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, { command = "checktime" })

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- go to last loc when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
  pattern = require("config").filetypes.ui,
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Show relative line numbers in visual modes
vim.api.nvim_create_autocmd("ModeChanged", { pattern = { "[vV\x16]*:*" }, command = ":setlocal norelativenumber" })
vim.api.nvim_create_autocmd("ModeChanged", { pattern = { "*:[vV\x16]*" }, command = ":setlocal relativenumber" })

-- Close cmdwin with <Esc>
vim.api.nvim_create_autocmd("CmdwinEnter", {
  callback = function()
    vim.keymap.set("n", "<Esc>", "<C-c><C-c>", { buffer = 0 })
  end,
})

local LARGE_BUF = 1000000

-- Disable some sources of slowdown in large buffers.
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  pattern = "*",
  group = vim.api.nvim_create_augroup("buf_large", { clear = true }),
  callback = function()
    local stats_ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
    if stats_ok and stats and (stats.size > LARGE_BUF) then
      local disabled = {}

      for path, cmd in pairs({
        copilot = function()
          vim.b.copilot_enabled = false
        end,
        cmp = function()
          require("cmp").setup.buffer({ enabled = false })
        end,
        syntax = "syntax off",
        indent_blankline = "IndentBlanklineDisable",
        treesitter_context = "TSContextDisable",
        treesitter_highlight = "TSBufDisable highlight",
        spell = function()
          vim.opt_local.spell = false
        end,
        folds = function()
          vim.opt_local.foldmethod = "manual"
        end,
        illuminate = function()
          require("illuminate").pause_buf()
        end,
        ufo = function()
          require("ufo").detach()
        end,
      }) do
        if type(cmd) == "function" then
          local ok = pcall(cmd)
          if ok then
            vim.notify(path .. " disabled", vim.log.levels.DEBUG)
            table.insert(disabled, path)
          else
            vim.notify("Failed to disable " .. path, vim.log.levels.ERROR)
          end
        elseif pcall(vim.cmd, cmd) then
          vim.notify(path .. " disabled with " .. cmd, vim.log.levels.DEBUG)
          table.insert(disabled, path)
        else
          vim.notify(cmd .. " failed", vim.log.levels.ERROR)
        end
      end

      vim.notify("Large file detected!\nDisabling:\n  " .. table.concat(disabled, "\n  "), vim.log.levels.INFO)
      vim.b.large_buf = true
    else
      vim.b.large_buf = false
    end
  end,
})
