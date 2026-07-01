local assert = require("luassert")

-- word.lua memoizes the codediff module and its results at module level;
-- reload it fresh for each describe block that needs different module state.
local function fresh_word()
  package.loaded["app.review.diff.word"] = nil
  return require("app.review.diff.word")
end

describe("word.compute (codediff available)", function()
  -- Plenary's child nvim runs --noplugin, so the default app never packadds
  -- codediff; add it explicitly.
  vim.cmd.packadd("codediff.nvim")
  local word = fresh_word()

  it("returns nil for identical lines", function()
    assert.is_nil(word.compute("same", "same"))
  end)

  it("returns extmark-ready 0-based end-exclusive ranges per side", function()
    -- del: "return 9 + 9"  add: "return nine(9) -- edited" — asymmetric on
    -- purpose: a silent swap of compute_diff's (original, modified) argument
    -- order would flip which side gets the larger span.
    local wd = word.compute("return nine(9) -- edited", "return 9 + 9")
    assert.is_table(wd)
    assert.is_true(#wd.added > 0)
    assert.is_true(#wd.removed > 0)
    local function span(ranges)
      local total = 0
      for _, h in ipairs(ranges) do
        assert.is_true(h.end_col > h.col)
        assert.is_true(h.col >= 0)
        total = total + (h.end_col - h.col)
      end
      return total
    end
    assert.is_true(span(wd.added) > span(wd.removed), "added side must carry the larger change")
    for _, h in ipairs(wd.added) do
      assert.equals("ReviewDiffAddWord", h.hl_group)
      assert.is_true(h.end_col <= #"return nine(9) -- edited")
    end
    for _, h in ipairs(wd.removed) do
      assert.equals("ReviewDiffDeleteWord", h.hl_group)
      assert.is_true(h.end_col <= #"return 9 + 9")
    end
  end)

  it("memoizes results by (add, del) pair", function()
    local a = word.compute("local x = 1", "local y = 1")
    local b = word.compute("local x = 1", "local y = 1")
    assert.is_table(a)
    assert.equals(a, b) -- same table, not just equal contents
    word.clear_cache()
    local c = word.compute("local x = 1", "local y = 1")
    assert.not_equals(a, c)
    assert.same(a, c)
  end)
end)

describe("word.compute (codediff unavailable)", function()
  -- Plenary runs it-blocks synchronously, so plain code before/after them
  -- works as block-scoped setup/teardown (plenary busted has no setup()).
  local real_mod = package.loaded["codediff.core.diff"]
  package.loaded["codediff.core.diff"] = nil
  local attempts = 0
  -- preload is searcher #1, so this shadows the real module
  package.preload["codediff.core.diff"] = function()
    attempts = attempts + 1
    error("simulated missing libvscode-diff")
  end
  local word = fresh_word()

  it("degrades to nil without raising", function()
    assert.is_nil(word.compute("aaa", "bbb"))
  end)

  it("attempts the require exactly once across many cache misses", function()
    -- codediff's module load can hit the network installer; a failed require
    -- is not cached by Lua, so word.lua must memoize the failure itself.
    for i = 1, 10 do
      assert.is_nil(word.compute("left " .. i, "right " .. i))
    end
    assert.equals(1, attempts)
  end)

  package.preload["codediff.core.diff"] = nil
  package.loaded["codediff.core.diff"] = real_mod
  fresh_word()
end)
