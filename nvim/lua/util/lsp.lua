---@class LspUtil
local LspUtil = {}

function LspUtil.lsp_active()
  for _, client in pairs(vim.lsp.get_clients()) do
    if client.server_capabilities then
      return true
    end
  end
  return false
end

---@param cb fun(client, buffer)
function LspUtil.on_attach(cb)
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      if not (args.data and args.data.client_id) then
        return
      end
      local buffer = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      cb(client, buffer)
    end,
  })
end

return LspUtil
