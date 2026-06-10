Config.add("stevearc/conform.nvim")

local formatters_by_ft = {
  lua = { "stylua" },
}

require("conform").setup({
  formatters_by_ft = formatters_by_ft,
  default_format_opts = {
    lsp_format = "fallback",
    timeout_ms = 1000,
  },
  format_on_save = function(bufnr)
    if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
      return
    end
    if vim.tbl_contains(Config.filetypes.ui, vim.bo[bufnr].filetype) then
      return
    end
    return {}
  end,
  notify_on_error = true,
  notify_no_formatters = false,
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.api.nvim_create_user_command("Format", function(args)
  local bufnr = vim.api.nvim_get_current_buf()

  if args.args == "info" then
    vim.cmd.ConformInfo()
    return
  end

  local function notify_state(enabled, scope)
    vim.notify("Autoformat " .. (enabled and "enabled" or "disabled") .. " (" .. scope .. ")")
  end

  if args.args == "enable" then
    if args.bang then
      vim.b[bufnr].disable_autoformat = false
      notify_state(true, "buffer")
    else
      vim.g.disable_autoformat = false
      notify_state(true, "global")
    end
    return
  end

  if args.args == "disable" then
    if args.bang then
      vim.b[bufnr].disable_autoformat = true
      notify_state(false, "buffer")
    else
      vim.g.disable_autoformat = true
      notify_state(false, "global")
    end
    return
  end

  if args.args == "toggle" then
    if args.bang then
      vim.b[bufnr].disable_autoformat = not vim.b[bufnr].disable_autoformat
      notify_state(not vim.b[bufnr].disable_autoformat, "buffer")
    else
      vim.g.disable_autoformat = not vim.g.disable_autoformat
      notify_state(not vim.g.disable_autoformat, "global")
    end
    return
  end

  local range = args.range > 0 and {
    start = { args.line1, 0 },
    ["end"] = { args.line2, math.huge },
  } or nil
  require("conform").format({ async = true, lsp_format = "fallback", range = range })
end, {
  range = true,
  bang = true,
  nargs = "?",
  complete = function()
    return { "enable", "disable", "toggle", "info" }
  end,
  desc = "Format buffer/range, or manage autoformat (enable/disable!/toggle/info)",
})
