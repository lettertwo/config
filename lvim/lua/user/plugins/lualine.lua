local Lualine = {}

function Lualine.config()
	if not lvim.builtin.lualine.active then
		return
	end

	lvim.builtin.lualine.sections.lualine_a = { "mode" }
	lvim.builtin.lualine.options.section_separators = { left = "", right = "" }
end

return Lualine
