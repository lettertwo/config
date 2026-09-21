local assert = require("luassert")
local Annotations = require("config.annotations")
local Anchor = require("config.annotations.anchor")

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

  it("reads its default signs from Anchor.default_signs, not a second literal", function()
    -- If init.lua carried its own copy of the signs table, changing
    -- Anchor.default_signs here would have no effect on what a fresh
    -- Annotations.setup() configures anchor.lua with.
    local original = Anchor.default_signs.pending
    Anchor.default_signs.pending = "Z"

    Annotations._reset()
    Annotations.setup({})

    local glyph = Anchor.record_state({})
    Anchor.default_signs.pending = original
    Annotations._reset()
    Annotations.setup({})

    assert.equals("Z", glyph)
  end)
end)
