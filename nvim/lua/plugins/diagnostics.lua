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

---@param diagnostics vim.Diagnostic[]
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

---@param diagnostics vim.Diagnostic[]
---@return vim.Diagnostic[]
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
    return assert(
      vim.diagnostic.severity[string.upper(severity)] --[[@as integer]],
      string.format("Invalid severity: %s", severity)
    )
  end
  return severity
end

---@param severity integer|string|{max?: string, min?: string}|table|nil
---@param diagnostics vim.Diagnostic[]
---@return vim.Diagnostic[]
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

  {
    "stevearc/quicker.nvim",
    event = "FileType qf",
    cmd = { "ToggleQuickfix", "ToggleLoclist", "RefreshQuickfix" },
    keys = {
      { "<leader>xq", "<cmd>ToggleQuickfix<cr>", desc = "Toggle QuickFix" },
      { "<leader>xl", "<cmd>ToggleLoclist<cr>", desc = "Toggle Locationlist" },
      { "<leader>xr", "<cmd>RefreshQuickfix<cr>", desc = "Refresh Quickfix/Loclist" },
    },
    ---@module "quicker"
    ---@type quicker.SetupOptions
    opts = {
      -- Local options to set for quickfix
      opts = {
        buflisted = false,
        number = false,
        relativenumber = false,
        signcolumn = "auto",
        winfixheight = true,
        wrap = false,
      },
      -- Set to false to disable the default options in `opts`
      use_default_opts = true,
      -- Keymaps to set for the quickfix buffer
      keys = {
        {
          ">",
          function()
            require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
          end,
          desc = "Expand quickfix content",
        },
        {
          "<",
          function()
            require("quicker").collapse()
          end,
          desc = "Collapse quickfix content",
        },
      },
      -- Callback function to run any custom logic or keymaps for the quickfix buffer
      -- on_qf = function(bufnr) end,
      edit = {
        -- Enable editing the quickfix like a normal buffer
        enabled = true,
        -- Set to true to write buffers after applying edits.
        -- Set to "unmodified" to only write unmodified buffers.
        autosave = "unmodified",
      },
      -- Keep the cursor to the right of the filename and lnum columns
      constrain_cursor = true,
      highlight = {
        -- Use treesitter highlighting
        treesitter = true,
        -- Use LSP semantic token highlighting
        lsp = true,
        -- Load the referenced buffers to apply more accurate highlights (may be slow)
        load_buffers = true,
      },
      -- Map of quickfix item type to icon
      type_icons = {
        E = icons.diagnostics.Error,
        W = icons.diagnostics.Warn,
        I = icons.diagnostics.Info,
        N = icons.diagnostics.Info,
        H = icons.diagnostics.Hint,
      },
      -- Border characters
      borders = {
        vert = " ",
        -- Strong headers separate results from different files
        strong_header = "━",
        strong_cross = "━",
        strong_end = "━",
        -- Soft headers separate results within the same file
        soft_header = "╌",
        soft_cross = "╌",
        soft_end = "╌",
      },
      -- Trim the leading whitespace from results
      trim_leading_whitespace = true,
      -- Maximum width of the filename column
      -- max_filename_width = function()
      --   return math.floor(math.min(95, vim.o.columns / 2))
      -- end,
      -- How far the header should extend to the right
      -- header_length = function(type, start_col)
      --   return vim.o.columns - start_col
      -- end,
    },
    config = function(_, opts)
      local quicker = require("quicker")

      quicker.setup(opts)

      vim.api.nvim_create_user_command("ToggleQuickfix", function()
        quicker.toggle()
      end, { desc = "Toggle Quickfix" })

      vim.api.nvim_create_user_command("ToggleLoclist", function()
        quicker.toggle({ loclist = true })
      end, { desc = "Toggle Locationlist" })

      vim.api.nvim_create_user_command("RefreshQuickfix", function()
        local win = vim.api.nvim_get_current_win()
        if quicker.is_open(win) then
          quicker.refresh(win)
        else
          quicker.refresh()
        end
      end, { desc = "Refresh Quickfix/Loclist" })
    end,
  },
  { "kevinhwang91/nvim-bqf", ft = "qf", opts = {} },

  -- better diagnostics list and others
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    ---@module "trouble"
    ---@type trouble.Config
    opts = {
      keys = {
        ["<CR>"] = "jump",
        ["<S-CR>"] = "jump_close",
      },
      modes = {
        ---@type trouble.Mode
        diagnostics = {
          mode = "diagnostics",
          focus = true,
          ---@type trouble.Window.opts
          preview = {
            type = "float",
            relative = "editor",
            title = "Preview",
            title_pos = "center",
            border = "rounded",
            size = { width = 1, height = 0.3 },
            position = { 0.3, 0 },
          },
        },
      },
    },

    keys = {
      { "]x", diagnostic_goto_next, desc = "Next diagnostic" },
      { "[x", diagnostic_goto_prev, desc = "Previous diagnostic" },
      { "<leader>xj", diagnostic_goto_next, desc = "Next diagnostic" },
      { "<leader>xk", diagnostic_goto_prev, desc = "Previous diagnostic" },
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Trouble: Show Workspace Diagnostics" },
      { "<leader>xT", "<cmd>Trouble telescope toggle<cr>", desc = "Trouble: Show Telescope" },
      { "<leader>S", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols outline" },
      { "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Trouble: Show Diagnostics" },
      { "<leader>xw", "<cmd>Trouble diagnostics toggle<cr>", desc = "Trouble: Show Workspace Diagnostics" },
      { "<leader>xD", require("util").toggle_diagnostics, desc = "Turn Diagnostics on/off" },
      { "<leader>ux", require("util").toggle_diagnostics, desc = "Turn Diagnostics on/off" },
      { "<leader>xs", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Search Diagnostics" },
      { "<leader>sx", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Diagnostics" },
      { "<leader>xS", "<cmd>Telescope diagnostics<cr>", desc = "Search Workspace Diagnostics" },
      { "<leader>sX", "<cmd>Telescope diagnostics<cr>", desc = "Workspace Diagnostics" },
    },
  },
}
