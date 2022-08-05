local surround = require("nvim-surround")
-- local keymap = require("keymap")

surround.setup({
  keymaps = {
    insert = "gs",
    insert_line = "gss",
  },
})

-- Configure buffer setup autocommand
local buffer_setup_group = vim.api.nvim_create_augroup("nvimSurroundBufferSetup", { clear = false })

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local keymap = require("keymap").buffer(0)
    keymap.normal.label("gs", "Surround")
    keymap.normal.label("gss", "Line")
    keymap.normal.label("ds", "Surround")
    keymap.normal.label("dss", "Nearest")
    keymap.normal.label("cs", "Surround")
    keymap.normal.label("css", "Nearest")
    -- TODO: Figure out how to show delimiters, aliases, etc. when surround is pending (see default config below)
    keymap.normal.label("csa", "Nearest <,>")
  end,
  group = buffer_setup_group,
})

-- require("nvim-surround").setup({
--     keymaps = { -- vim-surround style keymaps
--         insert = "ys",
--         insert_line = "yss",
--         visual = "S",
--         delete = "ds",
--         change = "cs",
--     },
--     delimiters = {
--         pairs = {
--             ["("] = { "( ", " )" },
--             [")"] = { "(", ")" },
--             ["{"] = { "{ ", " }" },
--             ["}"] = { "{", "}" },
--             ["<"] = { "< ", " >" },
--             [">"] = { "<", ">" },
--             ["["] = { "[ ", " ]" },
--             ["]"] = { "[", "]" },
--             -- Define pairs based on function evaluations!
--             ["i"] = function()
--                 return {
--                     require("nvim-surround.utils").get_input(
--                         "Enter the left delimiter: "
--                     ),
--                     require("nvim-surround.utils").get_input(
--                         "Enter the right delimiter: "
--                     )
--                 }
--             end,
--             ["f"] = function()
--                 return {
--                     require("nvim-surround.utils").get_input(
--                         "Enter the function name: "
--                     ) .. "(",
--                     ")"
--                 }
--             end,
--         },
--         separators = {
--             ["'"] = { "'", "'" },
--             ['"'] = { '"', '"' },
--             ["`"] = { "`", "`" },
--         },
--         HTML = {
--             ["t"] = "type", -- Change just the tag type
--             ["T"] = "whole", -- Change the whole tag contents
--         },
--         aliases = {
--             ["a"] = ">", -- Single character aliases apply everywhere
--             ["b"] = ")",
--             ["B"] = "}",
--             ["r"] = "]",
--             -- Table aliases only apply for changes/deletions
--             ["q"] = { '"', "'", "`" }, -- Any quote character
--             ["s"] = { ")", "]", "}", ">", "'", '"', "`" }, -- Any surrounding delimiter
--         },
--     },
--     highlight_motion = { -- Highlight before inserting/changing surrounds
--         duration = 0,
--     }
-- })
