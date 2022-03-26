-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile

-- LunarVim Builtins
require("plugins.bufferline").config()
require("plugins.cmp").config()
require("plugins.dap").config()
require("plugins.dashboard").config()
require("plugins.lualine").config()
require("plugins.nvim-tree").config()
require("plugins.telescope").config()
require("plugins.treesitter").config()
require("plugins.which-key").config()

-- Additional Plugins
lvim.plugins = {
	{ "~/Code/laserwave.nvim" }, -- { "lettertwo/laserwave.nvim" },
	{ "folke/trouble.nvim", cmd = "TroubleToggle" },
	{ "simrat39/symbols-outline.nvim", cmd = "SymbolsOutline" },
	{ "ntpeters/vim-better-whitespace" },
	{ "sindrets/diffview.nvim", event = "BufRead" },
	{ "f-person/git-blame.nvim", event = "BufRead" },
	{ "rktjmp/lush.nvim" },
	{
		"folke/persistence.nvim",
		event = "BufReadPre", -- this will only start session saving when an actual file was opened
		module = "persistence",
		config = function()
			require("plugins.persistence").config()
		end,
	},
	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			require("plugins.colorizer").config()
		end,
	},
	{
		"folke/todo-comments.nvim",
		event = "BufRead",
		config = function()
			require("todo-comments").setup()
		end,
	},
	{ "nvim-treesitter/playground", event = "BufRead" },
	{ "nvim-treesitter/nvim-treesitter-textobjects" },
	{ "RRethy/nvim-treesitter-textsubjects" },
	{ "andymass/vim-matchup" },
}
