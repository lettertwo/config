local surround = require("nvim-surround")

surround.setup({
  keymaps = {
    insert = "<C-g>s",
    insert_line = "<C-g>S",
    normal = "gs",
    normal_cur = "gss",
    normal_line = "gS",
    normal_cur_line = "gSS",
    visual = "S",
    visual_line = "gS",
    delete = "ds",
    change = "cs",
  },
})

-- Configure buffer setup autocommand
local buffer_setup_group = vim.api.nvim_create_augroup("nvimSurroundBufferSetup", { clear = false })

-- Add which-key descriptions for surround operations.
-- See which-key setup in `keymap.lua` for surround operators.
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local keymap = require("config.keymap").buffer(0)
    keymap.normal.register({
      gs = {
        name = "Surround",
        s = {
          name = "line",
          i = "interactive",
          f = "function",
          t = "<tag type>…</tag>",
          T = "<tag>…</tag>",
          a = "<…>",
          b = "(…)",
          B = "{…}",
          r = "[…]",
        },
      },
      gS = {
        name = "Surround with new lines",
        S = {
          name = "line",
          i = "interactive",
          f = "function",
          t = "<tag type>…</tag>",
          T = "<tag>…</tag>",
          a = "<…>",
          b = "(…)",
          B = "{…}",
          r = "[…]",
        },
      },
      ds = {
        name = "Surround",
        s = "smart",
        q = "quote",
        f = "function",
        t = "<tag type></tag>",
        T = "<tag></tag>",
        a = "<…>",
        b = "(…)",
        B = "{…}",
        r = "[…]",
      },
      cs = {
        name = "Surround",
        s = "smart",
        q = "quote",
        f = "function",
        t = "<tag type>…</tag>",
        T = "<tag>…</tag>",
        a = "<…>",
        b = "(…)",
        B = "{…}",
        r = "[…]",
      },
    })
  end,
  group = buffer_setup_group,
})
