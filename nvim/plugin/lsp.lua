Config.add("neovim/nvim-lspconfig")
Config.add("mrcjkb/rustaceanvim")
Config.add("b0o/schemastore.nvim")

vim.g.rustaceanvim = {
  server = {
    default_settings = {
      ["rust-analyzer"] = {
        cargo = {
          targetDir = true,
        },
        cachePriming = {
          enable = false,
        },
        check = {
          enable = true,
          command = "clippy",
          features = "all",
          extraArgs = { "--no-deps" },
        },
        files = {
          excludeDirs = {
            "target",
            "node_modules",
          },
        },
      },
    },
  },
}

vim.lsp.config("*", {
  root_markers = { ".git" },
})

vim.lsp.config("jsonls", {
  before_init = function(_, new_config)
    new_config.settings.json.schemas = new_config.settings.json.schemas or {}
    vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
  end,
  settings = {
    json = {
      format = { enable = true },
      validate = { enable = true },
    },
  },
})

vim.lsp.config("yaml", {
  before_init = function(_, new_config)
    new_config.settings.yaml.schemas = new_config.settings.yaml.schemas or {}
    vim.list_extend(new_config.settings.yaml.schemas, require("schemastore").yaml.schemas())
  end,
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      keyOrdering = false,
      format = { enable = true },
      validate = true,
      schemaStore = {
        -- Must disable built-in schemaStore support to use
        -- schemas from SchemaStore.nvim plugin
        enable = false,
        -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
        url = "",
      },
    },
  },
})

local servers = { "copilot", "lua_ls", "jsonls", "cssls", "html", "yamlls", "tombi" }
local enabled = vim.tbl_filter(function(name)
  local cfg = vim.lsp.config[name] or {}
  local cmd = type(cfg.cmd) == "table" and cfg.cmd[1] or cfg.cmd
  return type(cmd) == "function" or vim.fn.executable(cmd) == 1
end, servers)
vim.lsp.enable(enabled)

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
