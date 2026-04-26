Config.add("mfussenegger/nvim-lint")

local lint = require("lint")
lint.linters_by_ft = lint.linters_by_ft or {}

local function executable(name)
  local linter = lint.linters[name]
  if type(linter) == "function" then
    linter = linter()
  end
  if not linter then
    return false
  end
  local cmd = linter.cmd
  if type(cmd) == "function" then
    cmd = cmd()
  end
  return cmd and vim.fn.executable(cmd) == 1
end

local function try_lint(bufnr)
  if vim.g.disable_autolint or vim.b[bufnr].disable_autolint then
    return
  end
  if vim.tbl_contains(Config.filetypes.ui, vim.bo[bufnr].filetype) then
    return
  end
  local names = lint.linters_by_ft[vim.bo[bufnr].filetype] or {}
  local available = vim.tbl_filter(executable, names)
  if #available > 0 then
    lint.try_lint(available)
  end
end

Config.on({ "BufWritePost", "BufReadPost" }, function(ev)
  try_lint(ev.buf)
end, "Auto-lint")

vim.api.nvim_create_user_command("Lint", function(args)
  local bufnr = vim.api.nvim_get_current_buf()

  if args.args == "info" then
    local ft = vim.bo[bufnr].filetype
    local names = lint.linters_by_ft[ft] or {}
    local available, missing = {}, {}
    for _, name in ipairs(names) do
      if executable(name) then
        table.insert(available, name)
      else
        table.insert(missing, name)
      end
    end
    local lines = { "Lint info for filetype: " .. ft }
    if #names == 0 then
      table.insert(lines, "  No linters configured")
    else
      if #available > 0 then
        table.insert(lines, "  Available: " .. table.concat(available, ", "))
      end
      if #missing > 0 then
        table.insert(lines, "  Missing on PATH: " .. table.concat(missing, ", "))
      end
    end
    vim.notify(table.concat(lines, "\n"))
    return
  end

  local function notify_state(enabled, scope)
    vim.notify("Autolint " .. (enabled and "enabled" or "disabled") .. " (" .. scope .. ")")
  end

  if args.args == "enable" then
    if args.bang then
      vim.b[bufnr].disable_autolint = false
      notify_state(true, "buffer")
    else
      vim.g.disable_autolint = false
      notify_state(true, "global")
    end
    return
  end

  if args.args == "disable" then
    if args.bang then
      vim.b[bufnr].disable_autolint = true
      notify_state(false, "buffer")
    else
      vim.g.disable_autolint = true
      notify_state(false, "global")
    end
    return
  end

  if args.args == "toggle" then
    if args.bang then
      vim.b[bufnr].disable_autolint = not vim.b[bufnr].disable_autolint
      notify_state(not vim.b[bufnr].disable_autolint, "buffer")
    else
      vim.g.disable_autolint = not vim.g.disable_autolint
      notify_state(not vim.g.disable_autolint, "global")
    end
    return
  end

  try_lint(bufnr)
end, {
  bang = true,
  nargs = "?",
  complete = function()
    return { "enable", "disable", "toggle", "info" }
  end,
  desc = "Lint buffer, or manage autolint (enable/disable!/toggle/info)",
})

vim.keymap.set("n", "<leader>l", "<cmd>Lint<cr>", { desc = "Lint buffer" })
