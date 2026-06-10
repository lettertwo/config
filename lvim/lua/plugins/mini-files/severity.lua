local nsMiniFiles = vim.api.nvim_create_namespace("mini_files_severity")
local autocmd = vim.api.nvim_create_autocmd
local _, MiniFiles = pcall(require, "mini.files")

-- Cache for diagnostics
local diagnosticsCache = nil
local cacheTimeout = 2000 -- in milliseconds

---@type table<string, {symbol: string, hlGroup: string}>
---@param severity string
---@return string symbol, string hlGroup
local function mapSymbols(severity)
  local severityMap = {
    [vim.diagnostic.severity.ERROR] = {
      symbol = LazyVim.config.icons.diagnostics.Error or "✖",
      hlGroup = "DiagnosticError",
    },
    [vim.diagnostic.severity.WARN] = {
      symbol = LazyVim.config.icons.diagnostics.Warn or "⚠",
      hlGroup = "DiagnosticWarn",
    },
    [vim.diagnostic.severity.INFO] = {
      symbol = LazyVim.config.icons.diagnostics.Info or "ℹ",
      hlGroup = "DiagnosticInfo",
    },
    [vim.diagnostic.severity.HINT] = {
      symbol = LazyVim.config.icons.diagnostics.Hint or "➤",
      hlGroup = "DiagnosticHint",
    },
  }

  local result = severityMap[severity] or { symbol = "?", hlGroup = "NonText" }
  local severitySymbol = result.symbol
  local severityHlGroup = result.hlGroup
  return severitySymbol, severityHlGroup
end

---@param diagnostics vim.Diagnostic[]
---@return table
local function parseDiagnostics(diagnostics)
  local severityMap = {}
  local cwd = LazyVim.root.cwd()
  local escapedcwd = cwd and vim.pesc(cwd)
  escapedcwd = vim.fs.normalize(escapedcwd)
  -- Iterate through the diagnostics and build a map of file paths to their severity
  for _, diag in ipairs(diagnostics) do
    local filePath =
      vim.fs.normalize(diag.bufnr and vim.api.nvim_buf_get_name(diag.bufnr) or ""):gsub("^" .. escapedcwd .. "/", "")
    if filePath ~= "" then
      local severity = tonumber(diag.severity) or vim.diagnostic.severity.INFO

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
        -- If it's the last part, it's a file, so add it with its severity
        if i == #parts then
          severityMap[currentKey] = severity
        else
          -- If it's not the last part, it's a directory. Check if it exists. Take the minimum severity for files in that directory.
          severityMap[currentKey] = math.min(severityMap[currentKey] or severity, severity)
        end
      end
    end
  end

  return severityMap
end

---@param severityMap table
---@return nil
local function updateMiniWithSeverity(buf_id, severityMap)
  vim.schedule(function()
    local nlines = vim.api.nvim_buf_line_count(buf_id)
    local cwd = LazyVim.root.cwd()
    local escapedcwd = cwd and vim.pesc(cwd)
    escapedcwd = vim.fs.normalize(escapedcwd)

    for i = 1, nlines do
      local entry = MiniFiles.get_fs_entry(buf_id, i)
      if not entry then
        break
      end
      local relativePath = entry.path:gsub("^" .. escapedcwd .. "/", "")
      local severity = severityMap[relativePath]

      if severity then
        local symbol, hlGroup = mapSymbols(severity)
        vim.api.nvim_buf_set_extmark(buf_id, nsMiniFiles, i - 1, 0, {
          virt_text = { { symbol, hlGroup } },
          virt_text_pos = "right_align",
          hl_mode = "combine",
        })
      end
    end
  end)
end

---@param buf_id number?
---@return nil
local function updateDiagnostics(buf_id)
  local currentTime = os.time()

  if buf_id ~= nil and diagnosticsCache and currentTime - diagnosticsCache.time < cacheTimeout then
    updateMiniWithSeverity(buf_id, diagnosticsCache.severityMap)
  else
    local diagnostics = vim.diagnostic.get()
    local severityMap = parseDiagnostics(diagnostics)
    diagnosticsCache = {
      time = currentTime,
      severityMap = severityMap,
    }
    if buf_id ~= nil then
      updateMiniWithSeverity(buf_id, severityMap)
    end
  end
end

---@return nil
local function clearCache()
  diagnosticsCache = nil
end

local function augroup(name)
  return vim.api.nvim_create_augroup("MiniFiles_severity_" .. name, { clear = true })
end

local M = {}

function M.setup()
  autocmd("User", {
    group = augroup("start"),
    pattern = "MiniFilesExplorerOpen",
    callback = function()
      updateDiagnostics()
    end,
  })

  autocmd("User", {
    group = augroup("close"),
    pattern = "MiniFilesExplorerClose",
    callback = function()
      clearCache()
    end,
  })

  autocmd("User", {
    group = augroup("update"),
    pattern = "MiniFilesBufferUpdate",
    callback = function(args)
      updateDiagnostics(args.data.buf_id)
    end,
  })
end

return M
