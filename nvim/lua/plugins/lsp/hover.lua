local M = {}

function M.get_formatted_diagnostics()
  local lnum, col = unpack(vim.api.nvim_win_get_cursor(0))
  lnum = lnum - 1
  -- LSP servers can send diagnostics with `end_col` past the length of the line
  local line_length = #vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, true)[1]
  local diagnostics = vim.tbl_filter(function(d)
    return d.lnum == lnum and math.min(d.col, line_length - 1) <= col and (d.end_col >= col or d.end_lnum > lnum)
  end, vim.diagnostic.get(0, { lnum = lnum }))

  local lines = {}
  local highlights = {}
  -- TODO: Add grouping by source and severity.
  if not vim.tbl_isempty(diagnostics) then
    for i, diagnostic in ipairs(diagnostics) do
      local prefix = string.format("%s[%s]: ", diagnostic.source, diagnostic.code)
      local severity = vim.diagnostic.severity[diagnostic.severity]
      local highlight = "Diagnostic" .. severity:sub(1, 1) .. severity:sub(2):lower()
      -- TODO: Decide how to highlight prefix.
      local prefix_highlight = highlight
      local message_lines = vim.split(diagnostic.message, "\n")
      table.insert(lines, prefix .. message_lines[1])
      table.insert(highlights, { #prefix, highlight, prefix_highlight })
      for j = 2, #message_lines do
        table.insert(lines, string.rep(" ", #prefix) .. message_lines[j])
        table.insert(highlights, { 0, highlight })
      end
    end
  end
  return lines, highlights
end

M.hover = vim.lsp.with(function(_, result, ctx, opts)
  local lines, highlights = M.get_formatted_diagnostics()
  local util = vim.lsp.util

  if result and result.contents then
    if not vim.tbl_isempty(lines) then
      table.insert(lines, "---")
    end
    vim.list_extend(lines, util.convert_input_to_markdown_lines(result.contents, {}))
  end

  lines = util.trim_empty_lines(lines)

  if vim.tbl_isempty(lines) then
    return
  end

  local float_opts = vim.tbl_extend("keep", opts, {
    border = "rounded",
    focusable = true,
    focus_id = "hover",
    close_events = { "CursorMoved", "BufHidden", "InsertCharPre" },
  })

  local bufnr, _ = util.open_floating_preview(lines, "markdown", float_opts)

  for i, hi in ipairs(highlights) do
    local prefixlen, hiname, prefix_hiname = unpack(hi)
    if prefix_hiname then
      vim.api.nvim_buf_add_highlight(bufnr, -1, prefix_hiname, i - 1, 0, prefixlen)
    end
    vim.api.nvim_buf_add_highlight(bufnr, -1, hiname, i - 1, prefixlen, -1)
  end
end, {})

return M
