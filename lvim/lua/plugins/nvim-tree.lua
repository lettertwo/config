local NvimTree = {}

function NvimTree.config()
	if not lvim.builtin.nvimtree.active then
		return
	end

	lvim.builtin.nvimtree.setup.view.side = "right"
	lvim.builtin.nvimtree.show_icons.git = 1
	lvim.builtin.nvimtree.setup.hide_dotfiles = 0
	lvim.builtin.nvimtree.setup.auto_close = 1
end

return NvimTree
