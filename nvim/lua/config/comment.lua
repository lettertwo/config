require('Comment').setup({
  mappings = {
    ---Operator-pending mapping
    ---Includes `gcc`, `gbc`, `gc[count]{motion}` and `gb[count]{motion}`
    ---NOTE: These mappings can be changed individually by `opleader` and `toggler` config
    basic = true,
    ---Extra mapping
    ---Includes `gco`, `gcO`, `gcA`
    extra = true,
    ---Extended mapping
    ---Includes `g>`, `g<`, `g>[count]{motion}` and `g<[count]{motion}`
    extended = false,
  },
  -- From https://github.com/numToStr/Comment.nvim#-hooks
  -- and https://github.com/JoosepAlviste/nvim-ts-context-commentstring#commentnvim
  pre_hook = function(ctx)
    local U = require('Comment.utils')

    -- Determine whether to use linewise or blockwise commentstring
    local type = ctx.ctype == U.ctype.line and '__default' or '__multiline'

    -- Determine the location where to calculate commentstring from
    local location = nil
    if ctx.ctype == U.ctype.block then
        location = require('ts_context_commentstring.utils').get_cursor_location()
    elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
        location = require('ts_context_commentstring.utils').get_visual_start_location()
    end

    return require('ts_context_commentstring.internal').calculate_commentstring({
        key = type,
        location = location,
    })
  end,
})

local keymap = require("keymap")

-- Describe block comment keymaps
keymap.normal.label('gb',  "Toggle block comment")
keymap.normal.label('gbc', "Toggle block comment")
keymap.visual.label('gb',  "Toggle block comment")

-- Describe line comment keymaps
keymap.normal.label('gc', "Toggle line comment")
keymap.normal.label('gcc', "Toggle line comment")
keymap.visual.label('gc', "Toggle line comment")

-- Describe extra keymaps
keymap.normal.label('gco', 'Comment next line')
keymap.normal.label('gcO', 'Comment prev line')
keymap.normal.label('gcA', 'Comment end of line')
