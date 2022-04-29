local components = require("lvim.core.lualine.components")
local conditions = require("lvim.core.lualine.conditions")
local colors = require("lvim.core.lualine.colors")

local Lualine = {}

local persisting = {
	function()
		if vim.g.persisting then
			return " "
		elseif vim.g.persisting == false then
			return " "
		end
	end,
	color = { fg = colors.bg },
	cond = conditions.hide_in_width,
}

local treesitter = vim.tbl_extend("force", components.treesitter, { color = { fg = colors.bg } })

function Lualine.config()
	if not lvim.builtin.lualine.active then
		return
	end

	lvim.builtin.lualine.sections.lualine_a = { "mode" }
	lvim.builtin.lualine.options.section_separators = { left = "", right = "" }
	lvim.builtin.lualine.options.globalstatus = true
	lvim.builtin.lualine.sections.lualine_x = {
		components.diagnostics,
		components.lsp,
		components.filetype,
	}
	lvim.builtin.lualine.sections.lualine_z = { treesitter, persisting }
end

return Lualine
