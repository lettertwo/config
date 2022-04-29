local WhichKey = {}

function WhichKey.config()
	if not lvim.builtin.which_key.active then
		return
	end

	lvim.builtin.which_key.setup.plugins.presets.motions = true
	lvim.builtin.which_key.setup.plugins.presets.operators = true
	lvim.builtin.which_key.setup.plugins.presets.text_objects = true

	-- Use which-key to add extra bindings with the leader-key prefix
	lvim.builtin.which_key.mappings["P"] = { "<cmd>Telescope projects<CR>", "Projects" }
	lvim.builtin.which_key.mappings["t"] = {
		name = "+Trouble",
		r = { "<cmd>Trouble lsp_references<cr>", "References" },
		f = { "<cmd>Trouble lsp_definitions<cr>", "Definitions" },
		d = { "<cmd>Trouble document_diagnostics<cr>", "Diagnostics" },
		q = { "<cmd>Trouble quickfix<cr>", "QuickFix" },
		l = { "<cmd>Trouble loclist<cr>", "LocationList" },
		w = { "<cmd>Trouble workspace_diagnostics<cr>", "Diagnostics" },
		t = { "<cmd>Trouble telescope<cr>", "Telescope" },
	}
	lvim.builtin.which_key.mappings["<cr>"] = { "<cmd>update!<CR>", "Save, if changed" }
	lvim.builtin.which_key.mappings["b"] = vim.tbl_deep_extend("error", lvim.builtin.which_key.mappings["b"], {
		w = { "<cmd>w<CR>", "Write current buffer" },
		W = { "<cmd>wa<CR>", "Write all buffers" },
		u = { "<cmd>update<CR>", "Update current buffer" },
		c = { "<cmd>bd!<CR>", "Close current buffer" },
		C = { "<cmd>%bd|e#|bd#<CR>", "Close all buffers" },
		s = {
			function()
				local fname = vim.fn.input("Save as: ", vim.fn.bufname(), "file")
				if fname ~= "" then
					vim.cmd(":saveas! " .. fname)
				end
			end,
			"Save current buffer (as)",
		},
	})
	lvim.builtin.which_key.mappings["%"] = {
		name = "+File",
		s = { "<cmd source %<CR>", "Source current file" },
	}

	lvim.builtin.which_key.mappings["H"] = { "<cmd>Telescope highlights<CR>", "Highlights" }
end

return WhichKey
