Config.add("folke/snacks.nvim")

local opts = {
	notifier = { level = vim.log.levels.INFO },
	image = {},
	indent = {
		filter = function(buf)
			return vim.g.snacks_indent ~= false
				and vim.b[buf].snacks_indent ~= false
				and vim.bo[buf].buftype == ""
				and not vim.list_contains(Config.filetypes.ui, vim.bo[buf].filetype)
		end,
		animate = { enabled = false },
		indent = { char = "│" },
		scope = {
			enabled = true,
			only_current = true,
			char = "│",
		},
		chunk = {
			enabled = true,
			only_current = true,
			char = {
				corner_top = "╭",
				corner_bottom = "╰",
				horizontal = "─",
				vertical = "│",
				arrow = "─",
			},
		},
	},
	statuscolumn = {
		left = { "sign", "mark" }, -- priority of signs on the left (high to low)
		right = { "fold", "git" }, -- priority of signs on the right (high to low)
	},
}

-- require("snacks.dashboard").setup(opts)
require("snacks").setup(opts)

local map = vim.keymap.set

---------------------------------------------
-- extracted from default LazyVim keymaps
---------------------------------------------
-- stylua: ignore start
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete Buffer" })
map("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Delete Other Buffers" })

-- toggle options
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.inlay_hints():map("<leader>uh")

-- lazygit
if vim.fn.executable("lazygit") == 1 then
  map("n", "<leader>gg", function() Snacks.lazygit( { cwd = Config.root('git') }) end, { desc = "Lazygit (Root Dir)" })
  map("n", "<leader>gG", function() Snacks.lazygit() end, { desc = "Lazygit (cwd)" })
end

-- map("n", "<leader>gL", function() Snacks.picker.git_log() end, { desc = "Git Log (cwd)" })
-- map("n", "<leader>gb", function() Snacks.picker.git_log_line() end, { desc = "Git Blame Line" })
-- map("n", "<leader>gf", function() Snacks.picker.git_log_file() end, { desc = "Git Current File History" })
-- map("n", "<leader>gl", function() Snacks.picker.git_log({ cwd = LazyVim.root.git() }) end, { desc = "Git Log" })
-- map({ "n", "x" }, "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Git Browse (open)" })
-- map({"n", "x" }, "<leader>gY", function()
--   Snacks.gitbrowse({ open = function(url) vim.fn.setreg("+", url) end, notify = false })
-- end, { desc = "Git Browse (copy)" })
--
-- -- floating terminal
-- map("n", "<leader>fT", function() Snacks.terminal() end, { desc = "Terminal (cwd)" })
-- map("n", "<leader>ft", function() Snacks.terminal(nil, { cwd = LazyVim.root() }) end, { desc = "Terminal (Root Dir)" })
-- map({"n","t"}, "<c-/>",function() Snacks.terminal.focus(nil, { cwd = LazyVim.root() }) end, { desc = "Terminal (Root Dir)" })
-- map({"n","t"}, "<c-_>",function() Snacks.terminal.focus(nil, { cwd = LazyVim.root() }) end, { desc = "which_key_ignore" })
--
-- -- lua
-- map({"n", "x"}, "<localleader>r", function() Snacks.debug.run() end, { desc = "Run Lua", ft = "lua" })
