local assert = require("luassert")

describe("config.defaults", function()
  local config = require("app.review.config")

  it("binds the nav keys on both diff and outline", function()
    assert.equals("next_file", config.defaults.keys.diff["]f"])
    assert.equals("prev_changeset", config.defaults.keys.outline["[c"])
  end)

  it("binds the two selection ops only in the visual key table", function()
    assert.equals("stage_selection", config.defaults.keys.diff_visual["<leader>rs"])
    assert.is_nil(config.defaults.keys.diff["<leader>rs" .. "_selection"])
  end)

  it("shipped defaults produce zero warnings", function()
    local _, warnings = config.resolve(nil)
    assert.same({}, warnings)
  end)
end)

describe("config.resolve: merge", function()
  local config = require("app.review.config")

  it("an override replaces only the key it names, others stay default", function()
    local resolved, warnings = config.resolve({ keys = { diff = { ["]f"] = "toggle_layout" } } })
    assert.same({}, warnings)
    assert.equals("toggle_layout", resolved.keys.diff["]f"])
    assert.equals("prev_file", resolved.keys.diff["[f"])
  end)

  it("false unbinds a default key without a warning", function()
    local resolved, warnings = config.resolve({ keys = { outline = { ["a"] = false } } })
    assert.same({}, warnings)
    assert.is_nil(resolved.keys.outline["a"])
  end)

  it("a new key with a legal action for the view is accepted", function()
    local resolved, warnings = config.resolve({ keys = { outline = { ["<C-r>"] = "refresh" } } })
    assert.same({}, warnings)
    assert.equals("refresh", resolved.keys.outline["<C-r>"])
  end)
end)

describe("config.resolve: validation failures", function()
  local config = require("app.review.config")

  it("an unknown action warns and drops, the key's default stays live", function()
    local resolved, warnings = config.resolve({ keys = { diff = { ["]f"] = "next_fiel" } } })
    assert.equals(1, #warnings)
    assert.matches("unknown action", warnings[1])
    assert.matches("next_file", warnings[1]) -- suggestion
    assert.equals("next_file", resolved.keys.diff["]f"])
  end)

  it("an action with no handler for the view is illegal there", function()
    local resolved, warnings = config.resolve({ keys = { outline = { ["<Space>"] = "stage_file" } } })
    assert.equals(1, #warnings)
    assert.matches("no outline handler", warnings[1])
    assert.equals("stage", resolved.keys.outline["<Space>"])
  end)

  it("a non-string, non-false value warns and drops", function()
    local resolved, warnings = config.resolve({ keys = { diff = { ["]f"] = 1 } } })
    assert.equals(1, #warnings)
    assert.matches("must be an action name or false", warnings[1])
    assert.equals("next_file", resolved.keys.diff["]f"])
  end)

  it("<Esc> is reserved for the close cascade and can't be rebound", function()
    local resolved, warnings = config.resolve({ keys = { outline = { ["<Esc>"] = "close" } } })
    assert.equals(1, #warnings)
    assert.matches("reserved", warnings[1])
    assert.is_nil(resolved.keys.outline["<Esc>"])
  end)

  it("an unknown view name warns and its whole subtable is dropped", function()
    local resolved, warnings = config.resolve({ keys = { floob = { ["x"] = "close" } } })
    assert.equals(1, #warnings)
    assert.matches("not a known view", warnings[1])
    assert.is_nil(resolved.keys.floob)
  end)

  it("stage_selection is diff-only and Visual-mode: illegal on the outline", function()
    local _, warnings = config.resolve({ keys = { outline = { ["<Space>"] = "stage_selection" } } })
    assert.equals(1, #warnings)
  end)

  it("stage (Normal-mode diff) is illegal in the Visual key table", function()
    local _, warnings = config.resolve({ keys = { diff_visual = { ["<leader>rs"] = "stage" } } })
    assert.equals(1, #warnings)
  end)
end)

describe("config module cache", function()
  it("re-merges vim.g.review only after package.loaded is cleared", function()
    local saved = vim.g.review
    vim.g.review = { keys = { diff = { ["]f"] = false } } }
    package.loaded["app.review.config"] = nil
    local first = require("app.review.config")
    assert.is_nil(first.keys.diff["]f"])

    -- Changing vim.g.review without clearing the cache must NOT be picked
    -- up: this is the failure mode the gotcha warns about.
    vim.g.review = { keys = { diff = { ["]f"] = "prev_file" } } }
    local stale = require("app.review.config")
    assert.is_nil(stale.keys.diff["]f"])

    package.loaded["app.review.config"] = nil
    local fresh = require("app.review.config")
    assert.equals("prev_file", fresh.keys.diff["]f"])

    vim.g.review = saved
    package.loaded["app.review.config"] = nil
    require("app.review.config")
  end)
end)
