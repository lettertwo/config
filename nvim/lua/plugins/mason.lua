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
    print("Nothing to install")
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
    print("Nothing to clean")
  end
end

-- Package manager for LSP, DAP, Linting, Formatting, etc.
return {
  {
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "jay-babu/mason-nvim-dap.nvim",
    },
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonLog", "MasonInstallAll", "MasonClean" },
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
      vim.api.nvim_create_user_command("MasonClean", clean, {})
    end,
  },
}
