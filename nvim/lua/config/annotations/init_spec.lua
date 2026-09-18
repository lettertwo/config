local assert = require("luassert")
local Annotations = require("config.annotations")

-- `nvim_get_keymap` reports `lhs` with `<leader>` already resolved to the
-- actual key, not the literal string passed to `vim.keymap.set`.
local function find_keymap(mode, lhs)
  local resolved = lhs:gsub("<leader>", vim.g.mapleader or "\\")
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if map.lhs == resolved then
      return map
    end
  end
  return nil
end

describe("Config.Annotations setup", function()
  it("binds a caller-supplied keymap to the named action", function()
    Annotations._reset()
    Annotations.setup({ keymaps = { ["<leader>zz"] = "list" } })

    local map = find_keymap("n", "<leader>zz")
    assert.is_not_nil(map)
    assert.matches("list", map.desc)
  end)

  it("still binds the default keymaps alongside an override", function()
    Annotations._reset()
    Annotations.setup({ keymaps = { ["<leader>zz"] = "list" } })

    assert.is_not_nil(find_keymap("n", "<leader>aa"))
    assert.is_not_nil(find_keymap("x", "<leader>aa"))
  end)
end)
