--[[
lvim is the global options object

Linters should be
filled in as strings with either
a global executable or a path to
an executable
]]

-- general
lvim.log.level = "warn"
lvim.format_on_save = true
lvim.line_wrap_cursor_movement = true

-- vim.g.laserwave_style = "dark"
-- vim.g.laserwave_terminal_colors = true
-- vim.g.laserwave_italic_comments = true
-- vim.g.laserwave_italic_keywords = true
-- vim.g.laserwave_italic_functions = false
-- vim.g.laserwave_italic_variables = false
-- vim.g.laserwave_transparent = false
-- vim.g.laserwave_hide_inactive_statusline = false
-- vim.g.laserwave_sidebars = {}
-- vim.g.laserwave_transparent_sidebar = false
-- vim.g.laserwave_dark_sidebar = true
-- vim.g.laserwave_dark_float = true
-- vim.g.laserwave_colors = {}
-- vim.g.laserwave_light_brightness = 0.3
-- vim.g.laserwave_lualine_bold = false

lvim.colorscheme = "laserwave"

-- Don't highlight trailing whitespace for these filetypes
vim.g.better_whitespace_filetypes_blacklist = {
	"diff",
	"git",
	"gitcommit",
	"unite",
	"qf",
	"help",
	"markdown",
	"fugitive",
	"dashboard",
	"NvimTree",
	"Outline",
	"Trouble",
}

-- Don't show gitblame virtual text for these filetypes.
vim.g.gitblame_ignored_filetypes = { "NvimTree", "Outline", "Trouble" }

-- folding
vim.opt.foldcolumn = "1"
-- vim.opt.foldmethod = "expr"
-- vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevelstart = 99

-- keymappings [view all the defaults by pressing <leader>Lk]
-- unmap a default keymapping by setting it to false
lvim.leader = "space"
-- lvim.keys.normal_mode["<C-s>"] = ":w<cr>"

-- Cancel search highlighting with ESC
lvim.keys.normal_mode["<ESC>"] = ":nohlsearch<Bar>:echo<CR>"

-- Paste over selection (without yanking)
lvim.keys.visual_mode["p"] = '"_dP'

-- Indent and outdent visual selections
lvim.keys.visual_mode["H"] = "<gv"
lvim.keys.visual_mode["L"] = ">gv"

-- Change Telescope navigation to use j and k for navigation and n and p for history in both input and normal mode.
-- we use protected-mode (pcall) just in case the plugin wasn't loaded yet.
local _, actions = pcall(require, "telescope.actions")
lvim.builtin.telescope.defaults.mappings = {
	-- for input mode
	i = {
		["<C-j>"] = actions.move_selection_next,
		["<C-k>"] = actions.move_selection_previous,
		["<C-n>"] = actions.cycle_history_next,
		["<C-p>"] = actions.cycle_history_prev,
	},
	-- for normal mode
	n = {
		["<C-j>"] = actions.move_selection_next,
		["<C-k>"] = actions.move_selection_previous,
	},
}

-- Use which-key to add extra bindings with the leader-key prefix
lvim.builtin.which_key.mappings["P"] = { "<cmd>Telescope projects<CR>", "Projects" }
lvim.builtin.which_key.mappings["t"] = {
	name = "+Trouble",
	r = { "<cmd>Trouble lsp_references<cr>", "References" },
	f = { "<cmd>Trouble lsp_definitions<cr>", "Definitions" },
	d = { "<cmd>Trouble document_diagnostics<cr>", "Diagnostics" },
	q = { "<cmd>Trouble quickfix<cr>", "QuickFix" },
	l = { "<cmd>Trouble loclist<cr>", "LocationList" },
	w = { "<cmd>Trouble workspace_diagnostics<cr>", "Diagnostics" },
}
lvim.builtin.which_key.mappings["<cr>"] = { "<cmd>update!<CR>", "Save, if changed" }
lvim.builtin.which_key.mappings["b"] = vim.tbl_deep_extend("error", lvim.builtin.which_key.mappings["b"], {
	w = { "<cmd>w<CR>", "Write current buffer" },
	W = { "<cmd>wa<CR>", "Write all buffers" },
	u = { "<cmd>update<CR>", "Update current buffer" },
	c = { "<cmd>bd!<CR>", "Close current buffer" },
	C = { "<cmd>%bd|e#|bd#<CR>", "Close all buffers" },
	s = {
		function()
			local fname = vim.fn.input("Save as: ", vim.fn.bufname(), "file")
			if fname ~= "" then
				vim.cmd(":saveas! " .. fname)
			end
		end,
		"Save current buffer (as)",
	},
})
lvim.builtin.which_key.mappings["%"] = {
	name = "+File",
	s = { "<cmd source %<CR>", "Source current file" },
}

lvim.builtin.which_key.mappings["H"] = { "<cmd>Telescope highlights<CR>", "Highlights" }

lvim.builtin.which_key.mappings["S"] = {
	name = "Session",
	c = { "<cmd>lua require('persistence').load()<cr>", "Restore last session for current dir" },
	l = { "<cmd>lua require('persistence').load({ last = true })<cr>", "Restore last session" },
	Q = { "<cmd>lua require('persistence').stop()<cr>", "Quit without saving session" },
}

-- TODO: User Config for predefined plugins
-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile
lvim.builtin.dashboard.active = true
lvim.builtin.notify.active = true
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "right"
lvim.builtin.nvimtree.show_icons.git = 0

lvim.builtin.lualine.sections.lualine_a = { "mode" }
lvim.builtin.lualine.options.section_separators = { left = "", right = "" }

-- TODO: think about a `/` behavior like in Clover, etc.
-- TODO: finish importing config from nvim
-- TODO: explore converting dotfiles to .config
-- TODO: generate .tmtheme (can be used in bat)
-- TODO: generate iterm theme

lvim.builtin.bufferline.options.always_show_bufferline = true

-- if you don't want all the parsers change this to a table of the ones you want
lvim.builtin.treesitter.ensure_installed = {
	"bash",
	"c",
	"javascript",
	"json",
	"lua",
	"python",
	"typescript",
	"tsx",
	"css",
	"rust",
	"java",
	"yaml",
}

lvim.builtin.treesitter.ignore_install = { "haskell" }
lvim.builtin.treesitter.highlight.enabled = true

-- generic LSP settings

---@usage Select which servers should be configured manually. Requires `:LvimCacheReset` to take effect.
local servers = {
	"flow",
	tsserver = {
		-- Only activate tsserver if the project has config for it.
		root_dir = require("lspconfig").util.root_pattern("tsconfig.json", "jsconfig.json"),
	},
	"sumneko_lua",
}

-- See the full default list `:lua print(vim.inspect(lvim.lsp.override))`
vim.list_extend(lvim.lsp.override, servers)

---@usage setup a server -- see: https://www.lunarvim.org/languages/#overriding-the-default-configuration
local lsp_setup = require("lvim.lsp.manager").setup
for lsp, opts in pairs(servers) do
	if type(lsp) == "number" then
		lsp_setup(opts)
	else
		lsp_setup(lsp, opts)
	end
end

-- -- you can set a custom on_attach function that will be used for all the language servers
-- -- See <https://github.com/neovim/nvim-lspconfig#keybindings-and-completion>
lvim.lsp.on_attach_callback = function(client, bufnr)
	if client.name == "sumneko_lua" then
		client.resolved_capabilities.document_formatting = false
		client.resolved_capabilities.document_range_formatting = false
	end
end

-- set a formatter, this will override the language server formatting capabilities (if it exists)
local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup({
	{ command = "stylua" },
	{ command = "prettier" },
})

-- set additional linters
local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
	{ command = "eslint" },
})

-- set additional code actions
local code_actions = require("lvim.lsp.null-ls.code_actions")
code_actions.setup({
	{ command = "eslint" },
	{ command = "gitsigns" },
	{ command = "gitrebase" },
})

-- set additional diagnostics
local services = require("lvim.lsp.null-ls.services")
services.register_sources({ command = "eslint" }, "diagnostics")

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
			require("persistence").setup({
				dir = vim.fn.expand(vim.fn.stdpath("config") .. "/session/"),
				options = { "buffers", "curdir", "tabpages", "winsize" },
			})
		end,
	},
	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			require("colorizer").setup({ "*" }, {
				RGB = true, -- #RGB hex codes
				RRGGBB = true, -- #RRGGBB hex codes
				RRGGBBAA = true, -- #RRGGBBAA hex codes
				rgb_fn = true, -- CSS rgb() and rgba() functions
				hsl_fn = true, -- CSS hsl() and hsla() functions
				css = true, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
				css_fn = true, -- Enable all CSS *functions*: rgb_fn, hsl_fn
			})
		end,
	},
	{
		"karb94/neoscroll.nvim",
		event = "WinScrolled",
		config = function()
			require("neoscroll").setup()
		end,
	},
	{
		"folke/todo-comments.nvim",
		event = "BufRead",
		config = function()
			require("todo-comments").setup()
		end,
	},
}

-- Autocommands (https://neovim.io/doc/user/autocmd.html)
-- lvim.autocommands.custom_groups = {
--   { "BufWinEnter", "*.lua", "setlocal ts=8 sw=8" },
-- }
