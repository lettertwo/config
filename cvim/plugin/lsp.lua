Config.add("neovim/nvim-lspconfig")

vim.lsp.config("*", {
  root_markers = { ".git" },
})

local servers = { "copilot", "lua_ls" }
local enabled = vim.tbl_filter(function(name)
  local cfg = vim.lsp.config[name] or {}
  local cmd = cfg.cmd and cfg.cmd[1]
  return cmd and vim.fn.executable(cmd) == 1
end, servers)
vim.lsp.enable(enabled)

local function skip_typed_prefix(item, bufnr)
  if type(item.insert_text) ~= "string" or not item.range then
    return 0
  end
  local start_row, start_col = item.range:to_extmark()
  local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
  local first_line = item.insert_text:match("^[^\n]*")
  local rest = line:sub(start_col + 1)
  local i = 1
  while i <= #rest and i <= #first_line and rest:sub(i, i) == first_line:sub(i, i) do
    i = i + 1
  end
  return i - 1
end

local function next_word(suffix)
  return suffix:match("^[ \t]*[^%s]+") or suffix:match("^[ \t]+") or ""
end

local function next_line(suffix)
  local nl = suffix:find("\n", 1, true)
  if not nl then
    return suffix
  end
  -- When the suffix starts with \n the cursor is at end-of-line; take through
  -- the following line's end so the whole next line is accepted, not just a \n.
  if nl == 1 then
    local nl2 = suffix:find("\n", 2, true)
    return nl2 and suffix:sub(1, nl2) or suffix
  end
  return suffix:sub(1, nl)
end

local function get_completor(bufnr)
  local ok, Capability = pcall(require, "vim.lsp._capability")
  if not ok then
    return nil
  end
  local Completor = Capability.all and Capability.all["inline_completion"]
  return Completor and Completor.active and Completor.active[bufnr]
end

local function hide_inline_completion(bufnr)
  local completor = get_completor(bufnr)
  if completor and completor.current then
    completor:abort()
    return true
  end
end

local function partial_accept(take)
  return function(item)
    if type(item.insert_text) ~= "string" then
      return item
    end
    local bufnr = vim.api.nvim_get_current_buf()
    local skip = skip_typed_prefix(item, bufnr)
    local prefix = item.insert_text:sub(1, skip)
    local suffix = item.insert_text:sub(skip + 1)
    local accepted = take(suffix)
    local remaining = suffix:sub(#accepted + 1)
    -- Set the remaining text as the new current item before accept() fires so
    -- the TextChangedI → show() call that happens during insertion renders it
    -- immediately, preventing any visible virt-text flicker.
    if remaining ~= "" then
      local completor = get_completor(bufnr)
      if completor then
        completor.current = { _index = item._index, client_id = item.client_id, insert_text = remaining, range = nil }
      end
    end
    item.insert_text = prefix .. accepted
    return item
  end
end

Config.on("LspAttach", function(ev)
  local client = vim.lsp.get_client_by_id(ev.data.client_id)
  local buf = ev.buf
  if not client then
    return
  end
  local map = function(lhs, rhs, desc, method)
    if method and not client:supports_method(method) then
      return
    end
    vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc, nowait = true })
  end

  vim.keymap.set("n", "<leader>.", "gra", { buffer = buf, desc = "Code Actions", remap = true })

  local _, Snacks = pcall(require, "snacks")
  if Snacks ~= nil then
    -- stylua: ignore start
    map("grd", function() Snacks.picker.lsp_definitions() end,      "Definitions",      "textDocument/definition")
    map("grD", function() Snacks.picker.lsp_declarations() end,     "Declarations",     "textDocument/declaration")
    map("grr", function() Snacks.picker.lsp_references() end,       "References",       "textDocument/references")
    map("gri", function() Snacks.picker.lsp_implementations() end,  "Implementations",  "textDocument/implementation")
    map("grt", function() Snacks.picker.lsp_type_definitions() end, "Type Definitions", "textDocument/typeDefinition")
    map("grI", function() Snacks.picker.lsp_incoming_calls() end,   "Incoming Calls",   "callHierarchy/incomingCalls")
    map("grO", function() Snacks.picker.lsp_outgoing_calls() end,   "Outgoing Calls",   "callHierarchy/outgoingCalls")
    -- stylua: ignore end
  end

  if client.name == "copilot" then
    vim.lsp.inline_completion.enable(true, { bufnr = buf })

    vim.keymap.set("i", "<Tab>", function()
      if vim.fn.pumvisible() == 1 or not vim.lsp.inline_completion.get({ bufnr = buf }) then
        return "<Tab>"
      end
    end, { buffer = buf, expr = true, desc = "Accept the current inline completion" })

    vim.keymap.set("i", "<Right>", function()
      if
        vim.fn.pumvisible() == 1
        or not vim.lsp.inline_completion.get({ bufnr = buf, on_accept = partial_accept(next_word) })
      then
        return "<Right>"
      end
    end, { buffer = buf, expr = true, desc = "Accept the current inline completion word" })

    vim.keymap.set("i", "<Down>", function()
      if
        vim.fn.pumvisible() == 1
        or not vim.lsp.inline_completion.get({ bufnr = buf, on_accept = partial_accept(next_line) })
      then
        return "<Down>"
      end
    end, { buffer = buf, expr = true, desc = "Accept the current inline completion line" })

    vim.keymap.set("i", "<Left>", function()
      if not hide_inline_completion(buf) then
        return "<Left>"
      end
    end, { buffer = buf, expr = true, desc = "Hide the current inline completion" })

    vim.keymap.set("i", "<C-c>", function()
      if not hide_inline_completion(buf) then
        return "<C-c>"
      end
    end, { buffer = buf, expr = true, desc = "Hide the current inline completion" })
  end
end, "LSP buffer keymaps")

vim.api.nvim_create_user_command("Lsp", function(args)
  local bufnr = vim.api.nvim_get_current_buf()

  if args.args == "info" then
    vim.cmd("checkhealth vim.lsp")
    return
  end

  if args.args == "stop" then
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    local names = vim.tbl_map(function(c)
      return c.name
    end, clients)
    for _, client in ipairs(clients) do
      client:stop()
    end
    vim.notify(#names > 0 and "LSP stopped: " .. table.concat(names, ", ") or "LSP: no clients attached")
    return
  end

  if args.args == "start" then
    vim.cmd("doautocmd FileType")
    return
  end

  -- bare or "restart"
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local names = vim.tbl_map(function(c)
    return c.name
  end, clients)
  for _, client in ipairs(clients) do
    client:stop()
  end
  vim.schedule(function()
    vim.cmd("doautocmd FileType")
    if #names > 0 then
      vim.notify("LSP restarted: " .. table.concat(names, ", "))
    end
  end)
end, {
  nargs = "?",
  complete = function()
    return { "restart", "stop", "start", "info" }
  end,
  desc = "Restart LSP clients in buffer, or manage clients (start/stop/restart/info)",
})
