local Cmp = {}

function Cmp.config()
	local _, cmp = pcall(require, "cmp")
	local _, luasnip = pcall(require, "luasnip")

	if not cmp or not luasnip then
		return
	end

	local has_words_before = function()
		local line, col = unpack(vim.api.nvim_win_get_cursor(0))
		return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
	end

	local select_next = cmp.mapping.select_next_item()
	local select_prev = cmp.mapping.select_prev_item()
	local scroll_docs = cmp.mapping.scroll_docs

	local complete_or_jump = cmp.mapping(function(fallback)
		if cmp.visible() then
			if cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false }) then
				if luasnip and luasnip.jumpable(1) then
					luasnip.jump(1)
				end
				return
			end
		end

		if luasnip and luasnip.jumpable(1) then
			if not luasnip.jump(1) then
				fallback()
			end
		else
			fallback()
		end
	end)

	local select_next_or_jump = cmp.mapping(function(fallback)
		if cmp.visible() then
			cmp.select_next_item()
		elseif luasnip and luasnip.expand_or_jumpable() then
			luasnip.expand_or_jump()
		elseif has_words_before() then
			cmp.complete()
		else
			fallback()
		end
	end, { "i", "s" })

	local select_prev_or_jump = cmp.mapping(function(fallback)
		if cmp.visible() then
			cmp.select_prev_item()
		elseif luasnip and luasnip.jumpable(-1) then
			luasnip.jump(-1)
		else
			fallback()
		end
	end, { "i", "s" })

	lvim.builtin.cmp.mapping = {
		["<C-n>"] = select_next,
		["<C-j>"] = select_next,
		["<Down"] = select_next,
		["<C-p>"] = select_prev,
		["<C-k>"] = select_prev,
		["<Up>"] = select_prev,
		["<Right>"] = complete_or_jump,
		["<CR>"] = complete_or_jump,
		["<Tab>"] = select_next_or_jump,
		["<S-Tab>"] = select_prev_or_jump,
		["<C-d>"] = scroll_docs(-4),
		["<C-f>"] = scroll_docs(4),
	}
end

return Cmp
