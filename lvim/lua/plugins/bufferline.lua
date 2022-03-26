local Bufferline = {}

function Bufferline.config()
	if not lvim.builtin.bufferline.active then
		return
	end

	lvim.builtin.bufferline.options.always_show_bufferline = true
end

return Bufferline
