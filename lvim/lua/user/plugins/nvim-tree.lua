local NvimTree = {}

function NvimTree.config()
  if not lvim.builtin.nvimtree.active then
    return
  end

  lvim.builtin.nvimtree.setup.disable_netrw = false
  lvim.builtin.nvimtree.setup.view.side = "right"
  lvim.builtin.nvimtree.setup.hijack_unnamed_buffer_when_opening = true
  lvim.builtin.nvimtree.setup.actions.open_file.quit_on_open = true
end

return NvimTree
