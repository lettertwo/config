local cwd = vim.loop.cwd()
local is_plugin_dir = cwd ~= nil
  and cwd:find("occurrence.nvim", 1, true) ~= nil
	and vim.fs.find({ "occurrence.lua" }, { type = "file", path = "./lua" })[1] ~= nil

local opts = {
	operators = {
		["gs"] = {
			desc = "Surround marked occurrences",
			before = function(_, ctx)
				local ok, mini_surround = pcall(require, "mini.surround")
				if not ok then
					vim.notify("mini.surround not found", vim.log.levels.WARN)
					return false
				end

				-- HACK: Access mini.surround's internals via debug
				local H = nil
				local info = debug.getinfo(mini_surround.add, "u")
				for i = 1, info.nups do
					local name, value = debug.getupvalue(mini_surround.add, i)
					if name == "H" and type(value) == "table" then
						H = value
						break
					end
				end

				if not H or not H.get_surround_spec then
					vim.notify("Could not access mini.surround internals", vim.log.levels.WARN)
					return false
				end

				---@diagnostic disable-next-line: redefined-local
				local ok, surr_info = pcall(H.get_surround_spec, "output")

				if not ok or not surr_info or not surr_info.left or not surr_info.right then
					vim.notify("Invalid surround specification", vim.log.levels.WARN)
					return false
				end

				-- Store in context for operator to use
				ctx.surr_info = surr_info
				ctx.respect_selection_type = mini_surround.config.respect_selection_type
			end,
			operator = function(current, ctx)
				if not ctx.surr_info then
					return false
				end
				ctx.register = nil -- Don't yank replaced text to register
				if ctx.respect_selection_type then
					return vim.tbl_map(function(line)
						return ctx.surr_info.left .. line .. ctx.surr_info.right
					end, current.text)
				else
					return ctx.surr_info.left .. table.concat(current.text, "\n") .. ctx.surr_info.right
				end
			end,
		},
	},
}

if cwd ~= nil and is_plugin_dir then
	Config.link("lettertwo/occurrence.nvim", cwd)
	require("occurrence.dev").setup(opts)
else
	Config.once("BufReadPost", function()
		Config.add("lettertwo/occurrence.nvim")
		require("occurrence").setup(opts)
	end)
end
