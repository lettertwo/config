---@class Config.MiniAi
local MiniAiConfig = {}

function MiniAiConfig.setup()
  Config.add("nvim-mini/mini.nvim")

	local ai = require("mini.ai")
	local gen_ai_spec = require("mini.extra").gen_ai_spec
	ai.setup({
		n_lines = 500,
		custom_textobjects = {
			G = gen_ai_spec.buffer(),
			D = gen_ai_spec.diagnostic(),
			I = gen_ai_spec.indent(),
			V = gen_ai_spec.line(),
			N = gen_ai_spec.number(),
			b = ai.gen_spec.treesitter({ -- code block
				a = { "@block.outer", "@conditional.outer", "@loop.outer" },
				i = { "@block.inner", "@conditional.inner", "@loop.inner" },
			}),
			f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }), -- function
			t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
			e = { -- Word with case
				{ "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
				"^().*()$",
			},
			u = ai.gen_spec.function_call(), -- u for "Usage"
			U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }), -- without dot in function name

			C = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }), -- class
			-- comment; nvim-treesitter/nvim-treesitter-textobjects only defines "@comment.outer".
			c = ai.gen_spec.treesitter({ a = "@comment.outer", i = "@comment.inner" }), -- comment
		},
	})
end

return MiniAiConfig
