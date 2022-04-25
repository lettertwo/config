local Telescope = {}

function Telescope.config()
	if not lvim.builtin.telescope.active then
		return
	end

	-- Change Telescope navigation to use j and k for navigation and n and p for history in both input and normal mode.
	-- we use protected-mode (pcall) just in case the plugin wasn't loaded yet.
	local _, actions = pcall(require, "telescope.actions")
	local _, trouble = pcall(require, "trouble.providers.telescope")
	lvim.builtin.telescope.defaults.mappings = {
		-- for input mode
		i = {
			["<C-j>"] = actions.move_selection_next,
			["<C-k>"] = actions.move_selection_previous,
			["<C-n>"] = actions.cycle_history_next,
			["<C-p>"] = actions.cycle_history_prev,
			["<C-t>"] = trouble.open_with_trouble,
		},
		-- for normal mode
		n = {
			["<C-j>"] = actions.move_selection_next,
			["<C-k>"] = actions.move_selection_previous,
			["<C-t>"] = trouble.open_with_trouble,
		},
	}
	lvim.builtin.telescope.defaults.pickers.buffers = {
		mappings = {
			i = {
				["<c-d>"] = actions.delete_buffer + actions.move_to_top,
			},
			n = {
				["<c-d>"] = actions.delete_buffer + actions.move_to_top,
			},
		},
	}
end

return Telescope
