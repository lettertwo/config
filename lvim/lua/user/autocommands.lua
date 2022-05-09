lvim.autocommands.custom_groups = {
  { "InsertEnter", "*", ":set norelativenumber" },
  { "InsertLeave", "*", ":set relativenumber" },
  {
    "BufWritePost",
    "*/lua/user/*.lua,*'lua/user/*/*.lua",
    ':lua require("user").reload(vim.fn.expand("<afile>"))',
  },
  { "CursorHold", "*", ':lua vim.diagnostic.open_float({scope="line"})' },
}
