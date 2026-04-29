local map = vim.keymap.set

Config.add("nvim-mini/mini.nvim")

Config.once("BufReadPost", function()
	require("mini.trailspace").setup()
	require("mini.operators").setup()
	require("mini.bracketed").setup()

	require("mini.align").setup({
		-- Module mappings. Use `''` (empty string) to disable one.
		mappings = {
			start = "",
			start_with_preview = "ga",
		},
		modifiers = {
			["1"] = function(steps)
				table.insert(steps.pre_justify, require("mini.align").gen_step.filter("n == 1"))
			end,
		},
	})

	require("config.mini.ai").setup()
	require("config.mini.surround").setup()
end)

local ext3_blocklist = { scm = true, txt = true, yml = true }
local ext4_blocklist = { json = true, yaml = true }
require("mini.icons").setup({
  use_file_extension = function(ext, _)
    return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
  end,
})

require("config.mini.sessions").setup()
require("config.mini.files").setup()
