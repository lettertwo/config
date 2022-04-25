lvim.autocommands.custom_groups = {
	{ "InsertEnter", "*", ":set norelativenumber" },
	{ "InsertLeave", "*", ":set relativenumber" },
	{
		"BufWritePost",
		"*/lua/config/*.lua,*'lua/config/*/*.lua",
		':lua require("config").reload(vim.fn.expand("<afile>"))',
	},
}
