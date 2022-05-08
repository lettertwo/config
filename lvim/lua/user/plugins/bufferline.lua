local Bufferline = {}

function Bufferline.config()
  if not lvim.builtin.bufferline.active then
    return
  end

  lvim.builtin.bufferline.options.always_show_bufferline = true

  lvim.builtin.bufferline.keymap.normal_mode["<M-h>"] = ":BufferLineMovePrev<CR>"
  lvim.builtin.bufferline.keymap.normal_mode["<M-l>"] = ":BufferLineMoveNext<CR>"
end

return Bufferline
