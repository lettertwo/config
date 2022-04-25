-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile

-- LunarVim Builtins
require("config.plugins.bufferline").config()
require("config.plugins.cmp").config()
require("config.plugins.dap").config()
require("config.plugins.dashboard").config()
require("config.plugins.lualine").config()
require("config.plugins.nvim-tree").config()
require("config.plugins.telescope").config()
require("config.plugins.treesitter").config()
require("config.plugins.which-key").config()

-- Additional Plugins
lvim.plugins = {
	{
		"lettertwo/laserwave.nvim",
		requires = { "rktjmp/lush.nvim" },
	},
	{ "folke/trouble.nvim", cmd = "TroubleToggle" },
	{ "simrat39/symbols-outline.nvim", cmd = "SymbolsOutline" },
	{ "ntpeters/vim-better-whitespace" },
	{ "sindrets/diffview.nvim", event = "BufRead" },
	{ "f-person/git-blame.nvim", event = "BufRead" },
	{
		"folke/persistence.nvim",
		event = "BufReadPre", -- this will only start session saving when an actual file was opened
		module = "persistence",
		config = function()
			require("config.plugins.persistence").config()
		end,
	},
	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			require("config.plugins.colorizer").config()
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
	-- "sa" to add surround, "sd" to delete, "sr" to replace
	{ "machakann/vim-sandwich" },
	{ "knubie/vim-kitty-navigator" },
}
