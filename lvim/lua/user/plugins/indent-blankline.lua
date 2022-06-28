local IndentBlankline = {}

IndentBlankline.config = function()
  local _, indent_blankline = pcall(require, "indent_blankline")

  if not indent_blankline then
    return
  end

  indent_blankline.setup({
    show_current_context = true,
  })
end

return IndentBlankline
