return {
  {
    "numToStr/Comment.nvim",
    event = "BufReadPre",
    config = function()
      require("Comment").setup({
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
        -- From https://github.com/JoosepAlviste/nvim-ts-context-commentstring#commentnvim
        pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      })

      local keymap = require("config.keymap")

      -- Describe block comment keymaps
      keymap.normal.label("gb", "Toggle block comment")
      keymap.normal.label("gbc", "Toggle block comment")
      keymap.visual.label("gb", "Toggle block comment")

      -- Describe line comment keymaps
      keymap.normal.label("gc", "Toggle line comment")
      keymap.normal.label("gcc", "Toggle line comment")
      keymap.visual.label("gc", "Toggle line comment")

      -- Describe extra keymaps
      keymap.normal.label("gco", "Comment next line")
      keymap.normal.label("gcO", "Comment prev line")
      keymap.normal.label("gcA", "Comment end of line")
    end,
  },
}
