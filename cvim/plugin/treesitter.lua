vim.schedule(function()
	Config.add("romus204/tree-sitter-manager.nvim")

	require("tree-sitter-manager").setup({
		-- Optional: custom paths
		-- parser_dir = vim.fn.stdpath("data") .. "/site/parser",
		-- query_dir = vim.fn.stdpath("data") .. "/site/queries",
	})
end)
