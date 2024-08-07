local icons = require("config").icons

local function diagnostic_goto_next()
  vim.diagnostic.jump({ count = 1 })
end

local function diagnostic_goto_prev()
  vim.diagnostic.jump({ count = -1 })
end

vim.diagnostic.config({
  update_in_insert = true,
  underline = true,
  severity_sort = true,
  virtual_text = false,
  virtual_lines = false,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
      [vim.diagnostic.severity.WARN] = icons.diagnostics.Warn,
      [vim.diagnostic.severity.INFO] = icons.diagnostics.Info,
      [vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
    },
  },
  float = {
    focusable = false,
    close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
    style = "minimal",
    border = "rounded",
    source = true,
    header = "",
    prefix = "",
  },
})

---@param diagnostics Diagnostic[]
---@return integer
local function count_sources(diagnostics)
  local seen = {}
  local count = 0
  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.source and not seen[diagnostic.source] then
      seen[diagnostic.source] = true
      count = count + 1
    end
  end
  return count
end

---@param diagnostics Diagnostic[]
---@return Diagnostic[]
local function prefix_source(diagnostics)
  return vim.tbl_map(function(d)
    if not d.source then
      return d
    end

    local t = vim.deepcopy(d)
    t.message = string.format("%s: %s", d.source, d.message)
    return t
  end, diagnostics)
end

---@param severity string|integer
---@return integer
local function to_severity(severity)
  if type(severity) == "string" then
    return assert(vim.diagnostic.severity[string.upper(severity)], string.format("Invalid severity: %s", severity))
  end
  return severity
end

---@param severity integer|string|{max?: string, min?: string}|table|nil
---@param diagnostics Diagnostic[]
---@return Diagnostic[]
local function filter_by_severity(severity, diagnostics)
  if not severity then
    return diagnostics
  end

  if type(severity) ~= "table" then
    severity = to_severity(severity)
    return vim.tbl_filter(function(t)
      return t.severity == severity
    end, diagnostics)
  end

  if severity.min or severity.max then
    local min_severity = to_severity(severity.min) or vim.diagnostic.severity.HINT
    local max_severity = to_severity(severity.max) or vim.diagnostic.severity.ERROR

    return vim.tbl_filter(function(t)
      return t.severity <= min_severity and t.severity >= max_severity
    end, diagnostics)
  end

  local severities = {}
  for _, s in ipairs(severity) do
    severities[to_severity(s)] = true
  end

  return vim.tbl_filter(function(t)
    return severities[t.severity]
  end, diagnostics)
end

--- Format diagnostics for hover.
---
---@param opts table|nil Configuration table with the keys:
---            - bufnr: (number) Buffer number to show diagnostics from.
---                     Defaults to the current buffer.
---            - severity_sort: (default false) Sort diagnostics by severity.
---            - severity: (table) Severity to show. Defaults to all severities.
---@return {lines: string[], highlights: HoverHighlight[]} | nil
local function format_diagnostics(opts)
  opts = opts or { source = true }

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local lnum, col = unpack(vim.api.nvim_win_get_cursor(0))
  lnum = lnum - 1
  -- LSP servers can send diagnostics with `end_col` past the length of the line
  local line_length = #vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, true)[1]
  local diagnostics = vim.tbl_filter(function(d)
    return d.lnum == lnum and math.min(d.col, line_length - 1) <= col and (d.end_col >= col or d.end_lnum > lnum)
  end, vim.diagnostic.get(bufnr, { lnum = lnum }))

  if opts.severity then
    diagnostics = filter_by_severity(opts.severity, diagnostics)
  end

  if vim.tbl_isempty(diagnostics) then
    return
  end

  local severity_sort = vim.F.if_nil(opts.severity_sort, false)
  if severity_sort then
    if type(severity_sort) == "table" and severity_sort.reverse then
      table.sort(diagnostics, function(a, b)
        return a.severity > b.severity
      end)
    else
      table.sort(diagnostics, function(a, b)
        return a.severity < b.severity
      end)
    end
  end

  ---@type string[]
  local lines = {}
  ---@type HoverHighlight[]
  local highlights = {}

  if opts.source and (opts.source ~= "if_many" or count_sources(diagnostics) > 1) then
    diagnostics = prefix_source(diagnostics)
  end

  for i, diagnostic in ipairs(diagnostics) do
    local prefix = (#diagnostics <= 1) and "" or string.format("%d. ", i)
    local suffix = diagnostic.code and string.format(" [[%s]]", diagnostic.code) or ""

    local severity = vim.diagnostic.severity[diagnostic.severity]
    local hiname = "DiagnosticFloating" .. severity:sub(1, 1) .. severity:sub(2):lower()

    local message_lines = vim.tbl_map(function(value)
      value = string.gsub(value, "`", "``")
      return value
    end, vim.split(diagnostic.message, "\n"))

    for j = 1, #message_lines do
      local line = message_lines[j]
      local highlight = { hiname, #lines, 0, #line }

      if #prefix and j == 1 then
        line = prefix .. line
        highlight[3] = #prefix
      elseif #prefix then
        line = string.rep(" ", #prefix) .. line
      end

      if #suffix and j == #message_lines then
        line = line .. suffix
        highlight[4] = #line - #suffix
      end

      table.insert(lines, line)
      table.insert(highlights, highlight)
    end
  end

  return { lines = lines, highlights = highlights }
end

local function glance_diagnostics()
  -- TODO: Make float for diagnostics show lsp_lines
  return vim.diagnostic.open_float()
end

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("Diagnostics", {}),
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_create_autocmd("CursorHold", {
      group = vim.api.nvim_create_augroup("Diagnostics" .. bufnr, {}),
      buffer = bufnr,
      callback = function()
        -- TODO: Make float show again if moved to another diagnostic on same line
        if line ~= vim.api.nvim_win_get_cursor(0)[1] then
          line = vim.api.nvim_win_get_cursor(0)[1]
          glance_diagnostics()
        end
      end,
    })
  end,
})

require("util").register_hover({
  name = "Diagnostics",
  priority = 2,
  enabled = function()
    return vim.diagnostic.is_enabled()
  end,
  execute = function(done)
    local result = format_diagnostics()
    if result ~= nil and result.lines ~= nil and not vim.tbl_isempty(result.lines) then
      done(result)
    else
      done()
    end
  end,
})

return {
  {
    "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    cmd = { "LspLinesToggle" },
    event = "VeryLazy",
    keys = {
      { "<leader>ud", "<cmd>LspLinesToggle<cr>", desc = "Toggle LSP Lines" },
      { "<leader>xL", "<cmd>LspLinesToggle<cr>", desc = "Toggle LSP Lines" },
    },
    config = function()
      require("lsp_lines").setup()
      vim.api.nvim_create_user_command("LspLinesToggle", function()
        vim.diagnostic.config({ virtual_text = not require("lsp_lines").toggle() })
      end, { desc = "Toggle LspLines" })
    end,
  },

  -- better diagnostics list and others
  {
    "folke/trouble.nvim",
    cmd = { "TroubleToggle", "Trouble" },
    opts = {
      use_diagnostic_signs = true,
      auto_jump = { "lsp_definitions", "lsp_references", "lsp_type_definitions", "lsp_implementations" },
      action_keys = {
        jump = { "<CR>" },
        jump_close = { "<S-CR>" },
      },
    },
    keys = {
      { "<leader>xx", "<cmd>TroubleToggle<cr>", desc = "Trouble: Show" },
      -- { "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", desc = "Trouble: Show QuickFix" },
      -- { "<leader>xl", "<cmd>TroubleToggle loclist<cr>", desc = "Trouble: Show Locationlist" },
      { "<leader>xT", "<cmd>TroubleToggle telescope<cr>", desc = "Trouble: Show Telescope" },
      { "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Trouble: Show Diagnostics" },
      { "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Trouble: Show Workspace Diagnostics" },
      { "]x", diagnostic_goto_next, desc = "Next diagnostic" },
      { "[x", diagnostic_goto_prev, desc = "Previous diagnostic" },
      { "<leader>xj", diagnostic_goto_next, desc = "Next diagnostic" },
      { "<leader>xk", diagnostic_goto_prev, desc = "Previous diagnostic" },
      { "<leader>xD", require("util").toggle_diagnostics, desc = "Toggle Diagnostics" },
      { "<leader>ux", require("util").toggle_diagnostics, desc = "Toggle Diagnostics" },
      { "<leader>xs", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Search Diagnostics" },
      { "<leader>sx", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Diagnostics" },
      { "<leader>xS", "<cmd>Telescope diagnostics<cr>", desc = "Search Workspace Diagnostics" },
      { "<leader>sX", "<cmd>Telescope diagnostics<cr>", desc = "Workspace Diagnostics" },
    },
  },
}
