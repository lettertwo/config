local assert = require("luassert")
local pair = require("app.review.diff.pair")

local function ctx(text)
  return { kind = "ctx", text = text }
end
local function add(text)
  return { kind = "add", text = text }
end
local function del(text)
  return { kind = "del", text = text }
end

local function kinds(segs)
  return vim.tbl_map(function(s)
    return s.type
  end, segs)
end

describe("pair.segments", function()
  it("partitions a del-run followed by an add-run into one change segment", function()
    local segs = pair.segments({ ctx("a"), del("b"), del("c"), add("B"), add("C"), ctx("d") })
    assert.same({ "ctx", "change", "ctx" }, kinds(segs))
    assert.equals(2, #segs[2].dels)
    assert.equals(2, #segs[2].adds)
  end)

  it("handles pure-del and pure-add segments", function()
    local segs = pair.segments({ del("x"), ctx("a"), add("y") })
    assert.same({ "change", "ctx", "change" }, kinds(segs))
    assert.equals(1, #segs[1].dels)
    assert.equals(0, #segs[1].adds)
    assert.equals(0, #segs[3].dels)
    assert.equals(1, #segs[3].adds)
  end)

  it("splits add-before-del into two change segments", function()
    -- an add-run followed by a del-run is NOT one change pair
    local segs = pair.segments({ add("y"), del("x") })
    assert.same({ "change", "change" }, kinds(segs))
    assert.equals(1, #segs[1].adds)
    assert.equals(0, #segs[1].dels)
    assert.equals(1, #segs[2].dels)
  end)

  it("returns empty for empty input", function()
    assert.same({}, pair.segments({}))
  end)

  it("keeps interleaved runs as separate segments", function()
    local segs = pair.segments({
      del("a"), add("A"), ctx("k"), del("b"), del("c"), add("B"),
    })
    assert.same({ "change", "ctx", "change" }, kinds(segs))
    assert.equals(2, #segs[3].dels)
    assert.equals(1, #segs[3].adds)
  end)
end)
