vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Disable common built-in plugins
vim.g.loaded_2html_plugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1

if vim.env.FNM_DIR then
	vim.g.node_host_prog = vim.fs.joinpath(vim.fn.expand(vim.env.FNM_DIR), "aliases", "default", "bin", "node")
	vim.g.copilot_node_command = vim.g.node_host_prog
end

vim.g.pager = vim.env.KITTY_SCROLLBACK_NVIM == "true"

---@class Config
_G.Config = {
	filetypes = {
		ui = {
			"DiffviewFiles",
			"NeogitCommitSelectView",
			"NeogitCommitView",
			"NeogitConsole",
			"NeogitDiffView",
			"NeogitGitCommandHistory",
			"NeogitLogView",
			"NeogitPopup",
			"NeogitReflogView",
			"NeogitRefsView",
			"NeogitStashView",
			"NeogitStatus",
			"NvimTree",
			"Outline",
			"PlenaryTestPopup",
			"TelescopePrompt",
			"Trouble",
			"WhichKey",
			"alpha",
			"checkhealth",
			"cmp_menu",
			"dap-repl",
			"dap-view",
			"dap-view-repl",
			"dap-view-term",
			"dashboard",
			"dbout",
			"fugitive",
			"gitsigns-blame",
			"grug-far",
			"help",
			"lazy",
			"lspinfo",
			"man",
			"mason",
			"minifiles",
			"minipick",
			"ministarter",
			"neo-tree",
			"neo-tree-popup",
			"neotest-output",
			"neotest-output-panel",
			"neotest-summary",
			"noice",
			"notify",
			"packer",
			"qf",
			"sidekick_terminal",
			"snacks_dashboard",
			"snacks_notif",
			"snacks_picker",
			"snacks_picker_list",
			"snacks_terminal",
			"snacks_win",
			"spectre_panel",
			"startify",
			"startuptime",
			"terminal",
			"toggleterm",
			"trouble",
			"tsplayground",
			"unite",
			"wayfinder",
		},
	},
	-- stylua: ignore
	icons = {
		separator = "  ",
		dots      = "󰇘",
		prompt    = "  ",
		caret     = " ",
		multi     = " ",
		eob       = " ",
		tag       = "󰓹 ",
		fold = {
			foldclose = "",
			foldopen  = "",
			fold      = " ",
			foldsep   = " ",
		},
		dap = {
			Stopped             = { "󰁕 ", "DiagnosticWarn", "DapStoppedLine" },
			Breakpoint          = " ",
			BreakpointCondition = " ",
			BreakpointRejected  = { " ", "DiagnosticError" },
			LogPoint            = ".>",
		},
		diagnostics = {
			Error = " ",
			Warn  = " ",
			Hint  = " ",
			Info  = " ",
		},
		diff = {
			added    = " ",
			modified = " ",
			removed  = " ",
		},
		git = {
			staged    = " ",
			added     = "󰐕 ",
			deleted   = " ",
			ignored   = " ",
			modified  = " ",
			renamed   = " ",
			unmerged  = " ",
			untracked = " ",
		},
		task = {
			todo      = "󰄰 ",
			done      = "󰄴 ",
			active    = "󰪞 ",
			cancelled = "󱃓 ",
			important = "󰗖 ",
		},
		services = {
			copilot        = " ",
			diagnostics    = "󱤧 ",
			formatting     = "󰉼 ",
			not_persisting = " ",
			persisting     = "󰅟 ",
			treesitter     = " ",
		},
		kinds = {
			Array         = " ",
			Boolean       = "󰨙 ",
			Class         = " ",
			Codeium       = "󰘦 ",
			Collapsed     = " ",
			Color         = " ",
			Constant      = "󰏿 ",
			Constructor   = " ",
			Control       = " ",
			Copilot       = " ",
			Date          = "󱨰 ",
			DateTime      = "󱛡 ",
			Enum          = " ",
			EnumMember    = " ",
			Event         = " ",
			Field         = " ",
			File          = " ",
			Folder        = " ",
			Function      = "󰊕 ",
			Interface     = " ",
			Key           = " ",
			Keyword       = "󰌋 ",
			Label         = "󰀬 ",
			Method        = "󰊕 ",
			Module        = " ",
			Namespace     = "󰦮 ",
			Null          = "󰟢 ",
			Number        = " ",
			Object        = " ",
			Operator      = "󰆕 ",
			Package       = " ",
			Property      = " ",
			Reference     = " ",
			Snippet       = " ",
			String        = " ",
			Struct        = "󰆼 ",
			Supermaven    = " ",
			TabNine       = "󰏚 ",
			Text          = " ",
			TypeParameter = " ",
			Unit          = " ",
			Value         = " ",
			Variable      = "󰀫 ",
		},
	},
}

local CONFIG_GROUP = vim.api.nvim_create_augroup("Config", { clear = true })

---@alias Event vim.api.create_autocmd.callback.args
---@alias EventHandler fun(event: Event): boolean?

-- Create an autocommand that triggers on the specified event(s) and pattern(s).
---@param event string|string[] Autocommand event(s) to listen for.
---@param pattern string|string[] Optional pattern(s) to match.
---@param callback EventHandler Function to call when the event is triggered.
---@param desc string? Optional description for the autocommand.
---@overload fun(event: string|string[], callback: EventHandler, desc: string?): integer
function Config.on(event, pattern, callback, desc)
	---@type vim.api.keyset.create_autocmd.opts
	local opts = { group = CONFIG_GROUP }
	if type(pattern) == "function" then
		opts.callback = pattern
		---@cast callback -function+string?
		opts.desc = callback
	else
		opts.pattern = pattern
		opts.callback = callback
		opts.desc = desc
	end
	return vim.api.nvim_create_autocmd(event, opts)
end

-- Like `Config.on()`, but the autocommand will be removed after the first time it's triggered.
---@param event string|string[] Autocommand event(s) to listen for.
---@param pattern string|string[]? Optional pattern(s) to match.
---@param callback EventHandler Function to call when the event is triggered.
---@param desc string? Optional description for the autocommand.
---@overload fun(event: string|string[], callback: EventHandler, desc: string?): integer
function Config.once(event, pattern, callback, desc)
	---@type vim.api.keyset.create_autocmd.opts
	local opts = { group = CONFIG_GROUP, once = true }
	if type(pattern) == "function" then
		opts.callback = pattern
		---@cast callback -function+string?
		opts.desc = callback
	else
		opts.pattern = pattern
		opts.callback = callback
		opts.desc = desc
	end
	return vim.api.nvim_create_autocmd(event, opts)
end

-- Remove autocommands by ID or by event and pattern.
---@param id_or_event number|string Autocommand ID or event name to remove.
---@param pattern string? Optional pattern to further filter autocommands when removing by event.
function Config.off(id_or_event, pattern)
	if type(id_or_event) == "number" then
		return vim.api.nvim_del_autocmd(id_or_event)
	end
	for _, cmd in ipairs(vim.api.nvim_get_autocmds({ group = CONFIG_GROUP, event = id_or_event, pattern = pattern })) do
		vim.api.nvim_del_autocmd(cmd.id)
	end
end

-- Resolve plugin name to a full GitHub URL if it's in "user/repo" format.
---@param name string Plugin name, either in "user/repo" or "https://github.com/user/repo"
function Config.resolve_plugin_url(name)
	if not vim.startswith(name, "https://") then
		name = "https://github.com/" .. name
	end
	return name
end

-- Extract the "repo" part of "user/repo" or a full GitHub URL.
---@param name string Plugin name, either in "user/repo" or "https://github.com/user/repo"
function Config.parse_plugin_name(name)
	if vim.startswith(name, "https://") then
		name = name:match("https://github.com/(.+)")
	end
	return vim.split(name, "/")[2] or name
end

-- Add a plugin to the current session (via `vim.pack.add()`).
-- The plugin name can be specified either in "user/repo" format or as a full GitHub URL.
---@param name string Plugin name, either in "user/repo" or "https://github.com/user/repo"
function Config.add(name)
	vim.pack.add({ Config.resolve_plugin_url(name) })
end

-- Link a local plugin at the specified directory into the local pack directory.
-- The plugin name can be specified either in "user/repo" format or as a full GitHub URL.
---@param name string The name of the plugin to load in dev mode
---@param dir string The working directory of the plugin to load in dev mode
function Config.link(name, dir)
	name = Config.parse_plugin_name(name)
	vim.notify("Linking " .. name .. " from local path", vim.log.levels.DEBUG)
	local dev_name = name .. "-dev"
	local local_path = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "dev", "opt", dev_name)
	if vim.uv.fs_stat(local_path) then
		if vim.uv.fs_unlink(local_path) then
			vim.notify("Removed existing link at " .. local_path, vim.log.levels.TRACE)
		else
			vim.notify("Failed to remove existing link at " .. local_path, vim.log.levels.ERROR)
		end
	end
	-- create the parent directories for the local plugin path if they don't exist
	if vim.fn.mkdir(vim.fs.dirname(local_path), "p") then
		vim.notify("Created directories " .. vim.fs.dirname(local_path), vim.log.levels.TRACE)
	else
		vim.notify("Failed to create directories at " .. vim.fs.dirname(local_path), vim.log.levels.ERROR)
	end
	-- symlink the current directory to the local plugin path
	if vim.uv.fs_symlink(dir, local_path, { dir = true }) then
		vim.notify("Linked " .. local_path .. " to " .. dir, vim.log.levels.TRACE)
	else
		vim.notify("Failed to link " .. local_path .. " to " .. dir, vim.log.levels.ERROR)
	end

	vim.cmd.packadd(dev_name)
end

function Config.show_log()
	local log_file = vim.fs.joinpath(vim.fn.stdpath("log"), "nvim-pack.log")
	if vim.uv.fs_stat(log_file) then
		vim.cmd.edit(log_file)
	else
		vim.notify("No log file found at " .. log_file, vim.log.levels.WARN)
	end
end

function Config.get_git_branch()
	local git_dir = vim.fs.find(".git", { path = vim.fn.getcwd(), upward = true, type = "directory" })[1]
	if not git_dir then
		return nil
	end
	local f = io.open(git_dir .. "/HEAD", "r")
	if not f then
		return nil
	end
	local content = f:read("*l")
	f:close()
	return content and content:match("ref: refs/heads/(.+)")
end

---@type table<string, string>
local _basename_cache = {}

function Config.get_session_basename()
	-- Implementation based on `persistence.current()`.
	local cwd = vim.fn.getcwd()
	if _basename_cache[cwd] then
		return _basename_cache[cwd]
	end
	local name = cwd:gsub("[\\/:]+", "%%")
	local branch = Config.get_git_branch()
	if branch and branch ~= "main" and branch ~= "master" then
		name = name .. "%%" .. branch:gsub("[\\/:]+", "%%")
	end
	_basename_cache[cwd] = name

	-- Invalidate the cache when the directory changes or the editor gains focus.
	-- This is conservative, but makes it more likely that we won't see a stale session name.
	vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained" }, {
		once = true,
		callback = function()
			_basename_cache = {}
		end,
	})

	return name
end

---@param buf integer Buffer number to resolve the LSP root for.
---@return string?
local function resolve_lsp_root(buf)
	local bufpath = vim.api.nvim_buf_get_name(buf)
	if bufpath == "" or bufpath == nil then
		return nil
	end
	bufpath = vim.fs.normalize(bufpath)

	local roots = {}
	local clients = vim.lsp.get_clients({ bufnr = buf })
	for _, client in ipairs(clients) do
		if client.workspace_folders then
			for _, folder in ipairs(client.workspace_folders) do
				table.insert(roots, vim.uri_to_fname(folder.uri))
			end
		end
		if client.root_dir then
			table.insert(roots, client.root_dir)
		end
	end
	for _, root in ipairs(roots) do
		root = vim.fs.normalize(root)
		if bufpath:find(root, 1, true) == 1 then
			return root
		end
	end
end

local ROOT_PATTERNS = { ".git", "lua" }
local PACKAGE_PATTERNS = { "pkg.json", "package.json", "Cargo.toml" }
local WORKSPACE_PATTERNS = {
	"lazy-lock.json",
	"nvim-pack-lock.json",
	"yarn.lock",
	"package-lock.json",
	"pnpm-lock.yaml",
	"bun.lockb",
	"Cargo.lock",
}

---@enum (key) Config.Scope
-- Scope for resolving a root directory relative to a buffer.
Config.Scope = {
	git = "git", -- nearest .git root or cwd.
	root = "root", -- LSP root, or nearest .git root, or nearest parent with a root pattern, or cwd.
	workspace = "workspace", -- LSP root, or nearest parent with a workspace or root pattern, or cwd.
	package = "package", -- nearest parent with a package, workspace, or root pattern, or cwd.
}

-- Resolve a root path for the specified `scope` relative to the given `buf`.
-- If a root path cannot be found, falls back to `vim.uv.cwd()`
---@param scope Config.Scope? Optional scope that determines the method used to resolve the root:
-- `"git"`: nearest .git root or cwd.
-- `"root"`: LSP root, or nearest .git root, or nearest parent with a root pattern, or cwd.
-- `"workspace"`: LSP root, or nearest parent with a workspace or root pattern, or cwd.
-- `"package"`: nearest parent with a package, workspace, or root pattern, or cwd.
--
-- Defaults to `"root"`.
---@param buf integer? Optional buffer number to resolve the root for.
-- Defaults to the current buffer.
function Config.root(scope, buf)
	scope = scope or Config.Scope.root
	buf = buf or vim.api.nvim_get_current_buf()
	local res = nil
	if scope == Config.Scope.git then
		res = vim.fs.root(buf, ".git")
	elseif scope == Config.Scope.root then
		res = resolve_lsp_root(buf) or vim.fs.root(buf, ROOT_PATTERNS)
	elseif scope == Config.Scope.workspace then
		res = resolve_lsp_root(buf) or vim.fs.root(buf, { WORKSPACE_PATTERNS, ROOT_PATTERNS })
	elseif scope == Config.Scope.package then
		res = vim.fs.root(buf, { PACKAGE_PATTERNS, WORKSPACE_PATTERNS, ROOT_PATTERNS })
	end
	return res or vim.uv.cwd()
end

function Config.get_session_file()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "sessions", Config.get_session_basename() .. ".vim")
end

function Config.get_session_shadafile()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "shada", Config.get_session_basename() .. ".shada")
end

vim.cmd([[runtime! config/*.lua]])
