local assert = require("luassert")
local docket = require("app.review.docket")

describe("docket._gate", function()
  local function file(opts)
    opts = opts or {}
    return {
      path = "f.lua",
      head_ref = opts.head_ref or "WORKTREE",
      unstaged = opts.unstaged and {} or nil,
      staged_change = opts.staged and {} or nil,
    }
  end

  it("collapses to plain combined when the source can't stage", function()
    local stageable, zoom = docket._gate(false, file({ unstaged = true, staged = true }), "split")
    assert.is_false(stageable)
    assert.equals("combined", zoom)
  end)

  it("collapses non-worktree files (stack commits) to plain combined", function()
    local stageable, zoom = docket._gate(true, file({ head_ref = "abc123", unstaged = true }), "split")
    assert.is_false(stageable)
    assert.equals("combined", zoom)
  end)

  it("collapses files without sub-diffs to plain combined", function()
    local stageable, zoom = docket._gate(true, file(), "split")
    assert.is_false(stageable)
    assert.equals("combined", zoom)
  end)

  it("keeps the split only when both sub-diffs exist", function()
    local stageable, zoom = docket._gate(true, file({ unstaged = true, staged = true }), "split")
    assert.is_true(stageable)
    assert.equals("split", zoom)
  end)

  it("collapses the split to the side that exists", function()
    local _, zoom = docket._gate(true, file({ unstaged = true }), "split")
    assert.equals("unstaged", zoom)
    local _, zoom2 = docket._gate(true, file({ staged = true }), "split")
    assert.equals("staged", zoom2)
  end)

  it("falls back to combined when the requested single pane is absent", function()
    local _, zoom = docket._gate(true, file({ staged = true }), "unstaged")
    assert.equals("combined", zoom)
    local _, zoom2 = docket._gate(true, file({ unstaged = true }), "staged")
    assert.equals("combined", zoom2)
  end)

  it("honors an available single-pane request and combined", function()
    local stageable, zoom = docket._gate(true, file({ unstaged = true, staged = true }), "staged")
    assert.is_true(stageable)
    assert.equals("staged", zoom)
    local _, zoom2 = docket._gate(true, file({ unstaged = true, staged = true }), "combined")
    assert.equals("combined", zoom2)
  end)

  it("handles a nil file (empty docket)", function()
    local stageable, zoom = docket._gate(true, nil, "split")
    assert.is_false(stageable)
    assert.equals("combined", zoom)
  end)
end)
