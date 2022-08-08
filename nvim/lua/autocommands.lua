local join_paths = require("fs").join_paths
local commands = require("commands")

local configpath = vim.fn.stdpath("config")
local init_file = join_paths(configpath, "init.lua")

local default_opts = {
  group = vim.api.nvim_create_augroup("config", { clear = true }),
}

local M = {}

local function create(evt, opts)
  vim.api.nvim_create_autocmd(evt, vim.tbl_extend("force", default_opts, opts))
end

M.create = create

-- Show absolute line numbers in insert mode
create("InsertEnter", { pattern = { "*" }, command = ":set norelativenumber" })
create("InsertLeave", { pattern = { "*" }, command = ":set relativenumber" })

-- Reload config files
create("BufWritePost", {
  pattern = { init_file, "*/nvim/lua/*.lua", "*/nvim/lua/*/*.lua" },
  callback = function(evt)
    commands.ReloadConfig(evt.file:match("plugins.lua") ~= nil)
  end,
})

-- Close cmdwin with <Esc>
create("CmdwinEnter", {
  callback = function()
    require("keymap").buffer().normal("<Esc>", "<C-c><C-c>", "Exit Command")
  end,
})

-- Automatically format on save
create("BufWritePre", {
  pattern = { "*" },
  callback = function()
    vim.lsp.buf.format()
  end,
})

return M
