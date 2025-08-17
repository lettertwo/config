local ns = vim.api.nvim_create_namespace("oil_severity")

---@type table<string, {symbol: string, hl_group: string}>
---@param severity string
---@return string symbol, string hl_group
local function map_symbols(severity)
  local severity_map = {
    [vim.diagnostic.severity.ERROR] = {
      symbol = LazyVim.config.icons.diagnostics.Error or "✖",
      hl_group = "DiagnosticError",
    },
    [vim.diagnostic.severity.WARN] = {
      symbol = LazyVim.config.icons.diagnostics.Warn or "⚠",
      hl_group = "DiagnosticWarn",
    },
    [vim.diagnostic.severity.INFO] = {
      symbol = LazyVim.config.icons.diagnostics.Info or "ℹ",
      hl_group = "DiagnosticInfo",
    },
    [vim.diagnostic.severity.HINT] = {
      symbol = LazyVim.config.icons.diagnostics.Hint or "➤",
      hl_group = "DiagnosticHint",
    },
  }

  local result = severity_map[severity] or { symbol = "?", hl_group = "NonText" }
  local severity_symbol = result.symbol
  local severity_hl_group = result.hl_group
  return severity_symbol, severity_hl_group
end

---@param buffer number
---@param severity_map? table
---@return nil
local function add_severity_extmarks(buffer, severity_map)
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

  if not severity_map or vim.tbl_isempty(severity_map) then
    return
  end

  local cwd = LazyVim.root.cwd()
  local escapedcwd = cwd and vim.pesc(cwd)
  escapedcwd = vim.fs.normalize(escapedcwd)

  for i = 1, vim.api.nvim_buf_line_count(buffer) do
    local entry = oil.get_entry_on_line(buffer, i)

    if not dir or not entry then
      break
    end

    local path = vim.fs.joinpath(dir, entry.name)

    local relpath = path:gsub("^" .. escapedcwd .. "/", "")
    local severity = severity_map[relpath]

    if severity then
      local symbol, hl_group = map_symbols(severity)
      vim.api.nvim_buf_set_extmark(buffer, ns, i - 1, 0, {
        virt_text = { { symbol, hl_group } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
    end
  end
end

---@param diagnostics vim.Diagnostic[]
---@return table
local function parse_diagnostics(diagnostics)
  local severity_map = {}
  local cwd = LazyVim.root.cwd()
  local escapedcwd = cwd and vim.pesc(cwd)
  escapedcwd = vim.fs.normalize(escapedcwd)
  -- Iterate through the diagnostics and build a map of file paths to their severity
  for _, diag in ipairs(diagnostics) do
    local filepath =
      vim.fs.normalize(diag.bufnr and vim.api.nvim_buf_get_name(diag.bufnr) or ""):gsub("^" .. escapedcwd .. "/", "")
    if filepath ~= "" then
      local severity = tonumber(diag.severity) or vim.diagnostic.severity.INFO

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
        -- If it's the last part, it's a file, so add it with its severity
        if i == #parts then
          severity_map[current_key] = severity
        else
          -- If it's not the last part, it's a directory. Check if it exists. Take the minimum severity for files in that directory.
          severity_map[current_key] = math.min(severity_map[current_key] or severity, severity)
        end
      end
    end
  end

  return severity_map
end

---@param callback function
---@return nil
local function update_diagnostics(callback)
  vim.schedule(function()
    local diagnostics = vim.diagnostic.get()
    local severity_map = parse_diagnostics(diagnostics)
    callback(severity_map)
  end)
end

local M = {}

function M.setup()
  local augroup_oil_severity = vim.api.nvim_create_augroup("oil_severity", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = augroup_oil_severity,
    pattern = "OilEnter",
    callback = function(e)
      if vim.b[e.buf].oil_severity_started then
        return
      end

      vim.b[e.buf].oil_severity_started = true

      local severity_map = nil

      update_diagnostics(function(map)
        if not vim.api.nvim_buf_is_valid(e.buf) then
          return
        end

        severity_map = map
        add_severity_extmarks(e.buf, severity_map)

        vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave", "TextChanged" }, {
          group = augroup_oil_severity,
          buffer = e.buf,
          callback = function()
            update_diagnostics(function(map)
              if not vim.api.nvim_buf_is_valid(e.buf) then
                return
              end
              severity_map = map
              add_severity_extmarks(e.buf, severity_map)
            end)
          end,
        })
      end)
    end,
  })
end

return M
