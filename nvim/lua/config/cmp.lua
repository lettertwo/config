local cmp_status_ok, cmp = pcall(require, "cmp")
if not cmp_status_ok then
	return
end

local snip_status_ok, luasnip = pcall(require, "luasnip")
if not snip_status_ok then
	return
end

require("luasnip/loaders/from_vscode").lazy_load()

local function jump_or_fallback(fallback)
  if luasnip.jumpable(1) then
    if not luasnip.jump(1) then
      fallback()
    end
  else
    fallback()
  end
end

local function confirm_copilot_or_fallback(fallback)
  -- If a cmp selection wasn't confirmed, accept copilot suggestion if present.
  local copilot_status_ok, copilot_keys = pcall(vim.fn["copilot#Accept"], "")
  if copilot_status_ok and copilot_keys ~= "" then
    return vim.api.nvim_feedkeys(copilot_keys, "i", true)
  end
  fallback()
end

local function confirm()
  if cmp.confirm() then
    if luasnip.expand_or_jumpable(1) then
      return luasnip.expand_or_jump(1)
    end
    return true
  end
  return false
end

local function enter(fallback)
  if cmp.visible() and confirm() then
    return
  end
  jump_or_fallback(fallback)
end

local function right(fallback)
  if cmp.visible() and confirm() then
    print(1)
    return
  end
  if luasnip.jumpable(1) then
    print(2)
    jump_or_fallback(fallback)
  else
    print(3)
    confirm_copilot_or_fallback(fallback)
  end
end

local function tab(fallback)
  -- If a cmp selection is active, confirm it.
  if cmp.visible() and cmp.get_selected_entry() ~= nil and confirm() then
    return
  end
  confirm_copilot_or_fallback(fallback)
end

local kind_icons = {
	Text = "",
	Method = "",
	Function = "",
	Constructor = "",
	Field = "",
	Variable = "",
	Class = "",
	Interface = "",
	Module = "",
	Property = "",
	Unit = "",
	Value = "",
	Enum = "",
	Keyword = "",
	Snippet = "",
	Color = "",
	File = "",
	Reference = "",
	Folder = "",
	EnumMember = "",
	Constant = "",
	Struct = "",
	Event = "",
	Operator = "",
	TypeParameter = "",
}

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "nvim_lua", dup = 0 },
		{ name = "luasnip" },
    { name = "buffer" },
		{ name = "path" },
    { name = "calc" },
    { name = "emoji" },
    { name = "treesitter" },
    { name = "crates" },
  }),

	mapping = cmp.mapping.preset.insert({
    ["<C-k>"] = cmp.mapping.select_prev_item(),
    ["<C-j>"] = cmp.mapping.select_next_item(),
    ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
    ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
    ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
    ["<C-e>"] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),
    ["<Up>"] = cmp.mapping.select_prev_item(),
    ["<Down>"] = cmp.mapping.select_next_item(),
    ["<Right>"] = cmp.mapping(right, { "i", "c" }),
    ["<CR>"] = cmp.mapping(enter, { "i", "c" }),
    ["<Tab>"] = cmp.mapping(tab, { "i", "c" }),
    ["<S-Tab>"] = cmp.config.disable,
  }),
  enabled = function()
    if vim.bo.ft == "TelescopePrompt" then
      return false
    end
    return true
  end,
	formatting = {
		fields = {
      cmp.ItemField.Kind,
      cmp.ItemField.Abbr,
      cmp.ItemField.Menu,
    },
		format = function(entry, vim_item)
			vim_item.kind = kind_icons[vim_item.kind]
			vim_item.menu = ({
				nvim_lsp = "[LSP]",
				nvim_lua = "[lua]",
				luasnip = "[Snip]",
				buffer = "[Buf]",
				path = "[Path]",
				emoji = "[Emoji]",
			})[entry.source.name]
			return vim_item
		end,
	},
  sorting = {
    comparators = cmp.config.compare.recently_used,
  },
	confirm_opts = {
		behavior = cmp.ConfirmBehavior.Replace,
		select = false,
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	experimental = {
		ghost_text = true,
	}
})

-- Configuration for specific filetypes
cmp.setup.filetype("gitcommit", {
  sources = cmp.config.sources({
    { name = "cmp_git" },
  }, {
    { name = "buffer" },
  }),
})

cmp.setup.filetype("zsh", {
  sources = cmp.config.sources({
    { name = "zsh" },
  }, {
    { name = "buffer" },
  }),
})

cmp.setup.filetype("dap-repl", {
  sources = cmp.config.sources({
    { name = "dap" },
  }, {
    { name = "buffer" },
  }),
})

-- cmdline completion
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline({
    ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), {"c"}),
    ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), {"c"}),
  }),
  sources = {
    { name = 'cmdline' },
    { name = "cmdline_history" },
    { name = "path" },
  }
})

-- search completion
cmp.setup.cmdline('/', {
  mapping = cmp.mapping.preset.cmdline({
    ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), {"c"}),
    ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), {"c"}),
  }),
  sources = { { name = 'buffer' } }
})
cmp.setup.cmdline('?', {
  mapping = cmp.mapping.preset.cmdline({
    ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), {"c"}),
    ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), {"c"}),
  }),
  sources = { { name = 'buffer' } }
})
