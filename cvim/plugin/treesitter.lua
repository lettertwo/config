Config.on("PackChanged", function(ev)
	if ev.data.spec.name ~= "nvim-treesitter" then return end
	if ev.data.kind == "update" then
		vim.cmd("TSUpdate")
	end
end)

Config.add("nvim-treesitter/nvim-treesitter")

local pending = {} ---@type table<string, integer[]>

local function activate(bufnr, lang)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end
	vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
	pcall(vim.treesitter.start, bufnr)
end

-- Parser + locals.scm are both needed for full functionality (e.g. symbols picker).
local function is_ready(lang)
	return vim.treesitter.language.add(lang)
		and vim.treesitter.query.get(lang, "locals") ~= nil
end

local function poll(lang)
	if not is_ready(lang) then
		vim.defer_fn(function() poll(lang) end, 1000)
		return
	end
	for _, bufnr in ipairs(pending[lang] or {}) do
		activate(bufnr, lang)
	end
	pending[lang] = nil
end

Config.on("FileType", function(args)
	if vim.list_contains(Config.filetypes.ui, args.match) then return end
	local lang = vim.treesitter.language.get_lang(args.match)
	if not lang then return end
	if is_ready(lang) then
		activate(args.buf, lang)
		return
	end
	-- Activate highlighting immediately if the parser is available,
	-- even while waiting for nvim-treesitter to install full queries.
	if vim.treesitter.language.add(lang) then
		activate(args.buf, lang)
	end
	if not pending[lang] then
		pending[lang] = {}
		require("nvim-treesitter").install({ lang })
		poll(lang)
	end
	table.insert(pending[lang], args.buf)
end)
