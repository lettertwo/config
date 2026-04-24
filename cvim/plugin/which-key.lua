vim.schedule(function()
	Config.add("folke/which-key.nvim")

	require("which-key").setup({
		delay = 0,
		preset = "helix",
		spec = {
			{
				mode = { "n", "x" },
				{ "<leader><tab>", group = "tabs" },
				{ "<leader>c", group = "code" },
				{ "<leader>d", group = "debug" },
				{ "<leader>dp", group = "profiler" },
				{ "<leader>f", group = "file/find" },
				{ "<leader>g", group = "git" },
				{ "<leader>gh", group = "hunks" },
				{ "<leader>q", group = "quit/session" },
				{ "<leader>s", group = "search" },
				{ "<leader>u", group = "ui" },
				{ "<leader>x", group = "diagnostics/quickfix" },
				{ "[", group = "prev" },
				{ "]", group = "next" },
				{ "g", group = "goto" },
				{ "gs", group = "surround" },
				{ "gr", group = "lsp" },
        { "gra", desc = "Code Actions" },
        { "gri", desc = "Implementations" },
        { "grn", desc = "Rename" },
        { "grr", desc = "References" },
        { "grt", desc = "Type Definitions" },
        { "grx", desc = "Run Code Lens" },
				{ "z", group = "fold" },
				{ "<leader>b", group = "buffer" },
				{ "<leader>w", group = "windows", proxy = "<c-w>" },
			},
		},
	})
end)

local map = vim.keymap.set

map("n", "<leader>?", function()
	require("which-key").show({ global = false })
end, { desc = "Buffer Keymaps (which-key)" })

map("n", "<c-w><space>", function()
	require("which-key").show({ keys = "<c-w>", loop = true })
end, { desc = "Window Hydra Mode (which-key)" })
