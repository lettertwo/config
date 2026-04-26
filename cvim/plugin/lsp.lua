Config.add("neovim/nvim-lspconfig")

vim.lsp.config("*", {
  root_markers = { ".git" },
})

local servers = { "lua_ls" }
local enabled = vim.tbl_filter(function(name)
  local cfg = vim.lsp.config[name] or {}
  local cmd = cfg.cmd and cfg.cmd[1]
  return cmd and vim.fn.executable(cmd) == 1
end, servers)
vim.lsp.enable(enabled)

Config.on("LspAttach", function(ev)
  local client = vim.lsp.get_client_by_id(ev.data.client_id)
  if not client then
    return
  end
  local map = function(lhs, rhs, desc, method)
    if method and not client:supports_method(method) then
      return
    end
    vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc, nowait = true })
  end
	-- stylua: ignore start
	map("grd", function() Snacks.picker.lsp_definitions() end,      "Definitions",      "textDocument/definition")
	map("grD", function() Snacks.picker.lsp_declarations() end,     "Declarations",     "textDocument/declaration")
	map("grr", function() Snacks.picker.lsp_references() end,       "References",       "textDocument/references")
	map("gri", function() Snacks.picker.lsp_implementations() end,  "Implementations",  "textDocument/implementation")
	map("grt", function() Snacks.picker.lsp_type_definitions() end, "Type Definitions", "textDocument/typeDefinition")
	map("grI", function() Snacks.picker.lsp_incoming_calls() end,   "Incoming Calls",   "callHierarchy/incomingCalls")
	map("grO", function() Snacks.picker.lsp_outgoing_calls() end,   "Outgoing Calls",   "callHierarchy/outgoingCalls")
  vim.keymap.set("n", "<leader>.", "gra", { desc = "Code Actions", remap = true })
  -- stylua: ignore end
end, "LSP buffer keymaps")
