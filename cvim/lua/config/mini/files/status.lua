-- Based on https://gist.github.com/bassamsdata/eec0a3065152226581f8d4244cce9051

local nsMiniFiles = vim.api.nvim_create_namespace("mini_files_status")
local _, MiniFiles = pcall(require, "mini.files")

-- Cache for git status
local gitStatusCache = {}
local cacheTimeout = 2000 -- in milliseconds

---@type table<string, {symbol: string, hlGroup: string}>
---@param status string
---@return string symbol, string hlGroup
local function mapSymbols(status)
	local statusMap = {
		[" M"] = { symbol = Config.icons.git.modified or "•", hlGroup = "SnacksPickerGitStatusModified" }, -- Modified in t    he working directory
		["M "] = { symbol = Config.icons.git.staged or "✹", hlGroup = "SnacksPickerGitStatusStaged" }, -- modified in index
		["MM"] = { symbol = Config.icons.git.modified or "≠", hlGroup = "SnacksPickerGitStatusModified" }, -- modified in bot  h working tree and index
		["A "] = { symbol = Config.icons.git.added or "+", hlGroup = "SnacksPickerGitStatusAdded" }, -- Added to t          he staging area, new file
		["AA"] = { symbol = Config.icons.git.added or "≈", hlGroup = "SnacksPickerGitStatusAdded" }, -- file is added in both working tree and index
		["D "] = { symbol = Config.icons.git.removed or "-", hlGroup = "SnacksPickerGitStatusDeleted" }, -- Deleted from t    he staging area
		["AM"] = { symbol = Config.icons.git.added or "⊕", hlGroup = "SnacksPickerGitStatusAdded" }, -- added in working tree, modified in index
		["AD"] = { symbol = Config.icons.git.added or "-•", hlGroup = "SnacksPickerGitStatusAdded" }, -- Added in t          he index and deleted in the working directory
		["R "] = { symbol = Config.icons.git.renamed or "→", hlGroup = "SnacksPickerGitStatusRenamed" }, -- Renamed in t      he index
		["U "] = { symbol = Config.icons.git.conflict or "‖", hlGroup = "SnacksPickerGitStatusUnmerged" }, -- Unmerged pat     h
		["UU"] = { symbol = Config.icons.git.conflict or "⇄", hlGroup = "SnacksPickerGitStatusUnmerged" }, -- file is unmerged
		["UA"] = { symbol = Config.icons.git.conflict or "⊕", hlGroup = "SnacksPickerGitStatusUnmerged" }, -- file is unmerged and added in working tree
		["??"] = { symbol = Config.icons.git.untracked or "?", hlGroup = "SnacksPickerGitStatusUntracked" }, -- Untracked files
		["!!"] = { symbol = Config.icons.git.ignored or "!", hlGroup = "SnacksPickerGitStatusIgnored" }, -- Ignored files
	}

	local result = statusMap[status] or { symbol = "?", hlGroup = "NonText" }
	local gitSymbol = result.symbol
	local gitHlGroup = result.hlGroup
	return gitSymbol, gitHlGroup
end

---@param cwd string
---@param callback function
---@return nil
local function fetchGitStatus(cwd, callback)
	local clean_cwd = cwd:gsub("^minifiles://%d+/", "")
	---@param content table
	local function on_exit(content)
		if content.code == 0 then
			callback(content.stdout)
			-- vim.g.content = content.stdout
		end
	end
	---@see vim.system
	vim.system({ "git", "status", "--ignored", "--porcelain" }, { text = true, cwd = clean_cwd }, on_exit)
end

---@param buf_id integer
---@param gitStatusMap table
---@return nil
local function updateMiniWithGit(buf_id, gitStatusMap)
	vim.schedule(function()
		local nlines = vim.api.nvim_buf_line_count(buf_id)
		local cwd = vim.fs.root(buf_id, ".git")
		local escapedcwd = cwd and vim.pesc(cwd)
		escapedcwd = escapedcwd and vim.fs.normalize(escapedcwd)

		if not escapedcwd then
			return
		end

		for i = 1, nlines do
			local entry = MiniFiles.get_fs_entry(buf_id, i)
			if not entry then
				break
			end
			local relativePath = entry.path:gsub("^" .. escapedcwd .. "/", "")
			local status = gitStatusMap[relativePath]

			if status then
				local symbol, hlGroup = mapSymbols(status)
				vim.api.nvim_buf_set_extmark(buf_id, nsMiniFiles, i - 1, 0, {
					virt_text = { { symbol, hlGroup } },
					virt_text_pos = "right_align",
					hl_mode = "combine",
				})
				-- This below code is responsible for coloring the text of the items. comment it out if you don't want that
				local line = vim.api.nvim_buf_get_lines(buf_id, i - 1, i, false)[1]
				-- Find the name position accounting for potential icons
				local nameStartCol = line:find(vim.pesc(entry.name)) or 0

				if nameStartCol > 0 then
					vim.api.nvim_buf_set_extmark(buf_id, nsMiniFiles, i - 1, nameStartCol - 1, {
						end_col = nameStartCol + #entry.name - 1,
						hl_group = hlGroup,
					})
				end
			end
		end
	end)
end

-- Thanks for the idea of gettings https://github.com/refractalize/oil-git-status.nvim signs for dirs
---@param content string
---@return table
local function parseGitStatus(content)
	local gitStatusMap = {}
	-- lua match is faster than vim.split (in my experience )
	for line in content:gmatch("[^\r\n]+") do
		local status, filePath = string.match(line, "^(..)%s+(.*)")
		-- Split the file path into parts
		local parts = {}
		for part in filePath:gmatch("[^/]+") do
			table.insert(parts, part)
		end
		-- Start with the root directory
		local currentKey = ""
		for i, part in ipairs(parts) do
			if i > 1 then
				-- Concatenate parts with a separator to create a unique key
				currentKey = currentKey .. "/" .. part
			else
				currentKey = part
			end
			-- If it's the last part, it's a file, so add it with its status
			if i == #parts then
				gitStatusMap[currentKey] = status
			else
				-- If it's not the last part, it's a directory. Check if it exists, if not, add it.
				if not gitStatusMap[currentKey] then
					gitStatusMap[currentKey] = status
				end
			end
		end
	end
	return gitStatusMap
end

---@param buf_id integer
---@return nil
local function updateGitStatus(buf_id)
	local cwd = vim.fs.root(buf_id, ".git")
	if not cwd then
		return
	end
	local currentTime = os.time()

	if gitStatusCache[cwd] and currentTime - gitStatusCache[cwd].time < cacheTimeout then
		updateMiniWithGit(buf_id, gitStatusCache[cwd].statusMap)
	else
		fetchGitStatus(cwd, function(content)
			local gitStatusMap = parseGitStatus(content)
			gitStatusCache[cwd] = {
				time = currentTime,
				statusMap = gitStatusMap,
			}
			updateMiniWithGit(buf_id, gitStatusMap)
		end)
	end
end

---@return nil
local function clearCache()
	gitStatusCache = {}
end

local M = {}

function M.setup()
	Config.on("User", "MiniFilesExplorerOpen", function()
		local bufnr = vim.api.nvim_get_current_buf()
		updateGitStatus(bufnr)
	end)

	Config.on("User", "MiniFilesExplorerClose", clearCache)

	Config.on("User", "MiniFilesBufferUpdate", function(args)
		local bufnr = args.data.buf_id
		local cwd = vim.fs.root(bufnr, ".git")
		if gitStatusCache[cwd] then
			updateMiniWithGit(bufnr, gitStatusCache[cwd].statusMap)
		end
	end)
end

return M
