-- Based on https://gist.github.com/bassamsdata/eec0a3065152226581f8d4244cce9051

local ns = vim.api.nvim_create_namespace("oil_status")

---@type table<string, {symbol: string, hl_group: string}>
---@param status string
---@return string symbol, string hl_group
local function map_symbols(status)
  local status_map = {
    [" M"] = { symbol = LazyVim.config.icons.git.modified, hl_group = "SnacksPickerGitStatusModified" }, -- Modified in the working directory
    ["M "] = { symbol = LazyVim.config.icons.git.staged, hl_group = "SnacksPickerGitStatusStaged" }, -- modified in index
    ["MM"] = { symbol = LazyVim.config.icons.git.modified, hl_group = "SnacksPickerGitStatusModified" }, -- modified in both working tree and index
    ["A "] = { symbol = LazyVim.config.icons.git.added, hl_group = "SnacksPickerGitStatusAdded" }, -- Added to the staging area, new file
    ["AA"] = { symbol = LazyVim.config.icons.git.added, hl_group = "SnacksPickerGitStatusAdded" }, -- file is added in both working tree and index
    ["D "] = { symbol = LazyVim.config.icons.git.deleted, hl_group = "SnacksPickerGitStatusDeleted" }, -- Deleted from the staging area
    ["AM"] = { symbol = LazyVim.config.icons.git.added, hl_group = "SnacksPickerGitStatusAdded" }, -- added in working tree, modified in index
    ["AD"] = { symbol = LazyVim.config.icons.git.added, hl_group = "SnacksPickerGitStatusAdded" }, -- Added in the index and deleted in the working directory
    ["R "] = { symbol = LazyVim.config.icons.git.renamed, hl_group = "SnacksPickerGitStatusRenamed" }, -- Renamed in the index
    ["U "] = { symbol = LazyVim.config.icons.git.unmerged, hl_group = "SnacksPickerGitStatusUnmerged" }, -- Unmerged path
    ["UU"] = { symbol = LazyVim.config.icons.git.unmerged, hl_group = "SnacksPickerGitStatusUnmerged" }, -- file is unmerged
    ["UA"] = { symbol = LazyVim.config.icons.git.unmerged, hl_group = "SnacksPickerGitStatusUnmerged" }, -- file is unmerged and added in working tree
    ["??"] = { symbol = LazyVim.config.icons.git.untracked, hl_group = "SnacksPickerGitStatusUntracked" }, -- Untracked files
    ["!!"] = { symbol = LazyVim.config.icons.git.ignored, hl_group = "SnacksPickerGitStatusIgnored" }, -- Ignored files
  }

  local result = status_map[status] or { symbol = " ", hl_group = "NonText" }
  local git_symbol = result.symbol
  local git_hl_group = result.hl_group
  return git_symbol, git_hl_group
end

---@param cwd string
---@param callback function
---@return nil
local function fetch_git_status(cwd, callback)
  ---@param content table
  local function on_exit(content)
    if content.code == 0 then
      vim.schedule(function()
        callback(content.stdout)
      end)
    end
  end
  ---@see vim.system
  vim.system({ "git", "status", "--ignored", "--porcelain" }, { text = true, cwd = cwd }, on_exit)
end

---@param buffer integer
---@param git_status_map? table
---@return nil
local function add_status_extmarks(buffer, git_status_map)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buffer, ns, 0, -1)

  local oil_ok, oil = pcall(require, "oil")
  if not oil_ok then
    vim.error("oil.nvim is not installed")
  end

  local dir = oil.get_current_dir(buffer)
  if not dir then
    return
  end

  if not git_status_map or vim.tbl_isempty(git_status_map) then
    return
  end

  local cwd = LazyVim.root.git()
  local escapedcwd = cwd and vim.pesc(cwd)
  escapedcwd = vim.fs.normalize(escapedcwd)

  for i = 1, vim.api.nvim_buf_line_count(buffer) do
    local entry = oil.get_entry_on_line(buffer, i)

    if not dir or not entry then
      break
    end

    local path = vim.fs.joinpath(dir, entry.name)

    local relpath = path:gsub("^" .. escapedcwd .. "/", "")
    local status = git_status_map[relpath]

    if status then
      local symbol, hl_group = map_symbols(status)
      vim.api.nvim_buf_set_extmark(buffer, ns, i - 1, 0, {
        virt_text = { { symbol, hl_group } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
      local line = vim.api.nvim_buf_get_lines(buffer, i - 1, i, false)[1]
      -- Find the name position accounting for potential icons
      local name_start_col = line:find(vim.pesc(entry.name)) or 0

      if name_start_col > 0 then
        -- Find the name end position accounting for potential trailing slash
        local name_end_col = name_start_col + #entry.name
        if vim.fn.isdirectory(path) == 1 then
          name_end_col = name_end_col + 1
        end

        vim.api.nvim_buf_set_extmark(buffer, ns, i - 1, name_start_col - 1, {
          end_col = name_end_col - 1,
          hl_group = hl_group,
        })
      end
    end
  end
end

---@param content string
---@return table
local function parse_git_status(content)
  local git_status_map = {}

  ---@param status string
  ---@param filepath string
  local function map_status_for_path(status, filepath)
    if vim.fn.isdirectory(filepath) == 1 then
      for filename in vim.fs.dir(filepath) do
        map_status_for_path(status, vim.fs.joinpath(filepath, filename))
      end
    else
      -- Split the file path into parts
      local parts = {}
      for part in filepath:gmatch("[^/]+") do
        table.insert(parts, part)
      end
      -- Start with the root directory
      local current_key = ""
      for i, part in ipairs(parts) do
        if i > 1 then
          -- Concatenate parts with a separator to create a unique key
          current_key = current_key .. "/" .. part
        else
          current_key = part
        end
        -- If it's the last part, it's a file, so add it with its status
        if i == #parts then
          git_status_map[current_key] = status
        else
          -- If it's not the last part, it's a directory. Check if it exists, if not, add it.
          if not git_status_map[current_key] then
            git_status_map[current_key] = status
          end
        end
      end
    end
  end

  for line in content:gmatch("[^\r\n]+") do
    local status, filepath = string.match(line, "^(..)%s+(.*)")
    map_status_for_path(status, filepath)
  end

  return git_status_map
end

---@param buf_id integer
---@param callback function
---@return nil
local function update_git_status(buf_id, callback)
  vim.schedule(function()
    if #LazyVim.root.detect({ buf = buf_id, spec = { ".git" } }) < 1 then
      return
    end
    local cwd = LazyVim.root.git()

    fetch_git_status(cwd, function(content)
      local git_status_map = parse_git_status(content)
      callback(git_status_map)
    end)
  end)
end

local M = {}

function M.setup()
  local augroup_oil_status = vim.api.nvim_create_augroup("oil_status", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = augroup_oil_status,
    pattern = "OilEnter",
    callback = function(e)
      if vim.b[e.buf].oil_status_started then
        return
      end

      vim.b[e.buf].oil_status_started = true

      local status_map = nil

      update_git_status(e.buf, function(map)
        if not vim.api.nvim_buf_is_valid(e.buf) then
          return
        end

        status_map = map

        add_status_extmarks(e.buf, status_map)

        vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave", "TextChanged" }, {
          group = augroup_oil_status,
          buffer = e.buf,
          callback = function()
            update_git_status(e.buf, function(map)
              if not vim.api.nvim_buf_is_valid(e.buf) then
                return
              end
              status_map = map
              add_status_extmarks(e.buf, status_map)
            end)
          end,
        })
      end)
    end,
  })
end

return M
