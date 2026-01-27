local trouble_ok, trouble = pcall(require, "trouble")

local symbols = trouble_ok
  and trouble
  and trouble.statusline({
    mode = "symbols",
    groups = {},
    title = false,
    filter = { range = true },
    format = "{kind_icon}{symbol.name:Normal}",
    hl_group = "lualine_c_normal",
  })

return {
  symbols and symbols.get,
  cond = function()
    return symbols and symbols.has()
  end,
}
