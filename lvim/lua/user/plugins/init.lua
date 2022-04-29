-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile

-- LunarVim Builtins
require("user.plugins.bufferline").config()
require("user.plugins.cmp").config()
require("user.plugins.dap").config()
require("user.plugins.dashboard").config()
require("user.plugins.lualine").config()
require("user.plugins.nvim-tree").config()
require("user.plugins.telescope").config()
require("user.plugins.treesitter").config()
require("user.plugins.which-key").config()

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
			require("user.plugins.persistence").config()
		end,
	},
	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			require("user.plugins.colorizer").config()
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