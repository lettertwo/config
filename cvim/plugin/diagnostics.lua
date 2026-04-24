-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
vim.diagnostic.config({
	-- Show signs on top of any other sign, but only for warnings and errors
	signs = { priority = 9999, severity = { min = "WARN", max = "ERROR" } },

	-- Show all diagnostics as underline
	underline = { severity = { min = "HINT", max = "ERROR" } },

	-- Show virtual text only for errors on the current line
	virtual_lines = false,
	virtual_text = {
		current_line = true,
		severity = { min = "ERROR", max = "ERROR" },
	},

	-- Don't update diagnostics when typing
	update_in_insert = false,

	severity_sort = true,
	float = { border = "rounded", source = true, header = "", prefix = "" },
})
