local join_paths = require("fs").join_paths
local commands = require("commands")

local configpath = vim.fn.stdpath("config")
local init_file = join_paths(configpath, "init.lua")

local default_opts = {
  group = vim.api.nvim_create_augroup("config", { clear = true }),
}

local M = {}

local function create_autocmd(evt, opts)
  vim.api.nvim_create_autocmd(evt, vim.tbl_extend("force", default_opts, opts))
end

M.create_autocmd = create_autocmd

-- Show absolute line numbers in insert mode
create_autocmd("InsertEnter", { pattern = { "*" }, command = ":set norelativenumber" })
create_autocmd("InsertLeave", { pattern = { "*" }, command = ":set relativenumber" })

-- Reload config files
create_autocmd(
  "BufWritePost",
  { pattern = { init_file, "*/nvim/lua/*.lua", "*/nvim/lua/*/*.lua" }, callback = commands.ReloadConfig }
)

-- Close cmdwin with <Esc>
create_autocmd("CmdwinEnter", {
  callback = function()
    require("keymap").buffer().normal("<Esc>", "<C-c><C-c>", "Exit Command")
  end,
})

return M
