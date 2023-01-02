local default_opts = {
  group = vim.api.nvim_create_augroup("config", { clear = true }),
}

local M = {}

local function create(evt, opts)
  return vim.api.nvim_create_autocmd(evt, vim.tbl_extend("force", default_opts, opts))
end

local function remove(id)
  vim.api.nvim_del_autocmd(id)
end

M.create = create
M.remove = remove

-- Show absolute line numbers in insert mode
create("InsertEnter", { pattern = { "*" }, command = ":set norelativenumber" })
create("InsertLeave", { pattern = { "*" }, command = ":set relativenumber" })

-- Close cmdwin with <Esc>
create("CmdwinEnter", {
  callback = function()
    require("config.keymap").buffer().normal("<Esc>", "<C-c><C-c>", "Exit Command")
  end,
})

-- Automatically equalize window sizes.
create("VimResized", {
  callback = function()
    vim.cmd([[ wincmd = ]])
  end,
})

return M
