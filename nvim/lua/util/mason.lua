---@class MasonUtil
local MasonUtil = {}

---@class EnsureInstalled: string[]
-- A utility for managing what is installed by Mason.
-- It is a list of names of Mason-installable packages.
--
-- If called as a function, it will add the given packages to the list.
--
-- It may be called with a string, a list of strings, or a table that maps
-- some string, e.g., filetype, to a string or list of strings.
--
-- The function will return the original spec argument, so it may be used inline
-- for configuration.
--
-- Examples:
--
-- ```lua
-- -- Install the package "rust-analyzer"
-- require("util").ensure_installed("rust-analyzer")
-- -- Install the packages "rust-analyzer" and "clangd"
-- require("util").ensure_installed({ "rust-analyzer", "clangd" })
-- -- Configure formatters by filetype, and ensure that the formatters are installed
-- formatters_by_ft = require("util").ensure_installed({ javascript = { { "prettierd", "prettier" } } })
-- ```
--
---@overload fun(spec: string): string
---@overload fun(spec: string[]): string[]
---@overload fun(spec: {[string]: string | string[] | string[][]}): {[string]: string | string[] | string[][]}
MasonUtil.ensure_installed = {}

---@diagnostic disable-next-line: param-type-mismatch
setmetatable(MasonUtil.ensure_installed, {
  __call = function(self, spec)
    for _, value in pairs(type(spec) == "string" and { spec } or spec) do
      if type(value) == "string" then
        if not vim.list_contains(self, value) then
          table.insert(self, value)
        end
      elseif type(value) == "table" then
        MasonUtil.ensure_installed(value)
      else
        error("Invalid value type " .. type(value) .. " in spec")
      end
    end

    return spec
  end,
})

return MasonUtil
