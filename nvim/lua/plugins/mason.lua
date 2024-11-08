local Util = require("util")

---@return string[]
local function ensure_installed()
  local names = {}

  local ok_mlsp, mlsp = pcall(require, "mason-lspconfig.mappings.server")
  ---@diagnostic disable-next-line: cast-local-type
  mlsp = ok_mlsp and mlsp and mlsp.lspconfig_to_package or nil

  local ok_mdap, mdap = pcall(require, "mason-nvim-dap.mappings.source")
  ---@diagnostic disable-next-line: cast-local-type
  mdap = ok_mdap and mdap and mdap.nvim_dap_to_package or nil

  ---@diagnostic disable-next-line: param-type-mismatch
  for _, name in ipairs(Util.ensure_installed) do
    if mlsp and mlsp[name] then
      table.insert(names, mlsp[name])
    elseif mdap and mdap[name] then
      table.insert(names, mdap[name])
    else
      table.insert(names, name)
    end
  end

  return names
end

local function install_all()
  local names = ensure_installed()
  if #names > 0 then
    vim.cmd("MasonInstall " .. table.concat(names, " "))
  else
    vim.notify("Nothing to install", vim.log.levels.DEBUG, { title = "Mason" })
  end
end

local function clean()
  local names = ensure_installed()
  local to_uninstall = {}
  local registry = require("mason-registry")
  for _, name in ipairs(registry.get_all_package_names()) do
    if registry.is_installed(name) and not vim.tbl_contains(names, name) then
      table.insert(to_uninstall, name)
    end
  end

  if #to_uninstall > 0 then
    vim.cmd("MasonUninstall " .. table.concat(to_uninstall, " "))
  else
    vim.notify("Nothing to clean", vim.log.levels.DEBUG, { title = "Mason" })
  end
end

local function sync()
  local names = ensure_installed()
  local to_install = {}
  local to_uninstall = {}
  local registry = require("mason-registry")
  for _, name in ipairs(registry.get_all_package_names()) do
    if registry.is_installed(name) and not vim.tbl_contains(names, name) then
      table.insert(to_uninstall, name)
    end
  end
  for _, name in ipairs(names) do
    if not registry.is_installed(name) then
      table.insert(to_install, name)
    end
  end

  if #to_install > 0 then
    vim.cmd("MasonInstall " .. table.concat(to_install, " "))
  else
    vim.notify("Nothing to install", vim.log.levels.DEBUG, { title = "Mason" })
  end
  if #to_uninstall > 0 then
    vim.notify(
      "Run :MasonClean to clean up the following packages: " .. table.concat(to_uninstall, ", "),
      vim.log.levels.INFO,
      { title = "Mason" }
    )
  end
end

-- Package manager for LSP, DAP, Linting, Formatting, etc.
return {
  {
    "williamboman/mason.nvim",
    cond = vim.g.mergetool ~= true,
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "jay-babu/mason-nvim-dap.nvim",
    },
    cmd = {
      "Mason",
      "MasonInstall",
      "MasonUpdate",
      "MasonLog",
      "MasonInstall",
      "MasonUninstall",
      "MasonInstallAll",
      "MasonSync",
      "MasonClean",
    },

    keys = {
      { "<leader>M", "<cmd>Mason<cr>", desc = "Mason" },
      { "<leader>Pmm", "<cmd>Mason<cr>", desc = "Open" },
      { "<leader>Pml", "<cmd>MasonLog<cr>", desc = "Log" },
      { "<leader>Pmu", "<cmd>MasonUpdate<cr>", desc = "Update" },
      { "<leader>Pmi", ":MasonInstall", desc = "Install…" },
      { "<leader>Pmu", ":MasonUninstall", desc = "Uninstall…" },
      { "<leader>Pms", "<cmd>MasonSync<cr>", desc = "Sync" },
      { "<leader>PmI", "<cmd>MasonInstallAll<cr>", desc = "Install All" },
      { "<leader>PmC", "<cmmd>MasonClean<cr>", desc = "Clean" },
    },
    event = "VeryLazy",
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)
      require("mason-lspconfig").setup()
      require("mason-nvim-dap").setup()

      vim.api.nvim_create_user_command("MasonInstallAll", install_all, {})
      vim.api.nvim_create_user_command("MasonSync", sync, {})
      vim.api.nvim_create_user_command("MasonClean", clean, {})

      vim.schedule(sync)
    end,
  },
}
