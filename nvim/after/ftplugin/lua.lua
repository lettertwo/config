-- i?. expands to i ~= nil and i.<cursor>
vim.keymap.set("i", "?.", " ~= <Esc>2Byt~f=a nil and <Esc>pr.a", { buffer = true })
-- i += expands to i = i + <cursor>
vim.keymap.set("i", "+=", "= <Esc>2Byt=f=lpa+ ", { buffer = true })
-- i -= expands to i = i - <cursor>
vim.keymap.set("i", "-=", "= <Esc>2Byt=f=lpa- ", { buffer = true })
-- i ?= expands to i ~= nil and i = <cursor>
vim.keymap.set("i", "?=", "~= <Esc>2Byt~f=a nil and <Esc>pa= ", { buffer = true })

vim.b.minisurround_config = {
  custom_surroundings = {
    s = {
      input = { "%[%[().-()%]%]" },
      output = { left = "[[", right = "]]" },
    },
    ["F"] = {
      output = { left = "function() ", right = " end" },
    },
  },
}
