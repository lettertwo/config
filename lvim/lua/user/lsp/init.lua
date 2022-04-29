local Log = require("lvim.core.log")

---@usage Select which servers should be configured manually. Requires `:LvimCacheReset` to take effect.
local servers = {
	"flow",
	tsserver = {
		-- Only activate tsserver if the project has config for it.
		root_dir = require("lspconfig").util.root_pattern("tsconfig.json", "jsconfig.json"),
	},
	"sumneko_lua",
}

-- Exempt our manually configured servers from automatic configuration
local skipped_servers = lvim.lsp.automatic_configuration.skipped_servers
for k, v in pairs(servers) do
	if type(k) == "number" then
		k = v
	end
	if not vim.tbl_contains(skipped_servers, k) then
		Log:debug("Skipping automatic lsp config for  " .. k)
		table.insert(skipped_servers, k)
	end
end

---@usage setup a server -- see: https://www.lunarvim.org/languages/#overriding-the-default-configuration
local lsp_setup = require("lvim.lsp.manager").setup
for lsp, opts in pairs(servers) do
	if type(lsp) == "number" then
		lsp_setup(opts)
	else
		lsp_setup(lsp, opts)
	end
end

-- -- you can set a custom on_attach function that will be used for all the language servers
-- -- See <https://github.com/neovim/nvim-lspconfig#keybindings-and-completion>
-- lvim.lsp.on_attach_callback = function(client, bufnr)
-- 	if client.name == "sumneko_lua" then
-- 		client.resolved_capabilities.document_formatting = false
-- 		client.resolved_capabilities.document_range_formatting = false
-- 	end
-- end

-- set a formatter, this will override the language server formatting capabilities (if it exists)
local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup({
	{ command = "stylua" },
	{ command = "prettier", filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" } },
})

-- set additional linters
local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
	{ command = "eslint" },
})

-- set additional code actions
local code_actions = require("lvim.lsp.null-ls.code_actions")
code_actions.setup({
	{ command = "eslint" },
	{ command = "gitsigns" },
	{ command = "gitrebase" },
})

-- set additional diagnostics
local services = require("lvim.lsp.null-ls.services")
services.register_sources({ command = "eslint" }, "diagnostics")
