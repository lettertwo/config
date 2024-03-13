local create_buffer_keymap = require("util").create_buffer_keymap

local function rename()
  if vim.fn.exists(":IncRename") == 2 then
    return ":IncRename "
  else
    return ":lua vim.lsp.buf.rename()<cr>"
  end
end

---@type LspKeySpec[]
local keys = {
  { "gK", vim.lsp.buf.signature_help, desc = "Show signature help", has = "signatureHelp" },
  { "<leader>R", rename, desc = "Rename", expr = true, has = "rename" },
  { "<leader>lh", vim.lsp.buf.hover, desc = "Show hover" },
  { "<leader>lr", rename, desc = "Rename", expr = true, has = "rename" },
  { "<leader>ls", vim.lsp.buf.signature_help, desc = "Show signature help" },
}

---@class LspKeySpec: BufferKeySpec
---@field has? string Only if the LSP client and has the given capability.

---@class LspKeyCtx: BufferKeyCtx
---@field client table

---@class LspBufferKeymap: BufferKeymap
---@field apply fun(ctx: LspKeyCtx, specs?: LspKeySpec[])
local M = create_buffer_keymap({
  keys = keys,
  ---@param spec LspKeySpec
  ---@param ctx LspKeyCtx
  filter = function(spec, ctx)
    -- stylua: ignore start
    if not spec.has then return true end
    if not ctx.client then return false end
    if not ctx.client.server_capabilities then return false end
    if ctx.client.server_capabilities[spec.has] then return true end
    if ctx.client.server_capabilities[spec.has .. "Provider"] then return true end
    return false
    -- stylua: ignore end
  end,
  get_opts = function(opts)
    opts.has = nil
    return opts
  end,
})

function M.on_attach(client, buffer)
  if client.server_capabilities then
    M.apply({ buffer = buffer, client = client })
  end
end

return M
