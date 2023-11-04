local Util = require("util")

local M = {}

function M.on_attach(client, buffer)
  local inlay_hint = vim.lsp.buf.inlay_hint or vim.lsp.inlay_hint
  if inlay_hint ~= nil and client.supports_method("textDocument/inlayHint") then
    inlay_hint(buffer, true)

    local toggle_inlay_hint = Util.create_toggle("inlay_hints", "b", function(enabled)
      inlay_hint(buffer, enabled)
    end)

    require("plugins.lsp.keymaps").apply({ buffer = buffer, client = client }, {
      { "<leader>li", toggle_inlay_hint, desc = "Toggle inlay hints" },
      { "<leader>uL", toggle_inlay_hint, desc = "Toggle inlay hints" },
    })
  end
end

return M
