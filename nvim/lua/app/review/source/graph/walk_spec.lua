local assert = require("luassert")
local walk = require("app.review.source.graph.walk")

local function row(branch, parent, head_rev, parent_rev)
  return { branch = branch, parent = parent, head_rev = head_rev or "", parent_rev = parent_rev or "" }
end

describe("walk.walk", function()
  local by = {
    ["feat-a"] = row("feat-a", "main", "aaa111", "000aaa"),
    ["feat-b"] = row("feat-b", "feat-a", "bbb222", "aaa111"),
    ["feat-c"] = row("feat-c", "feat-b", "ccc333", "bbb222"),
    unrelated = row("unrelated", "main", "ddd444", "000aaa"),
  }

  it("walks parents from the focus branch in base→head order", function()
    local nodes = walk.walk(by, "feat-c")
    assert.same({ "feat-a", "feat-b", "feat-c" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
    assert.equals("000aaa", nodes[1].parent_rev)
    assert.equals("ccc333", nodes[3].head_rev)
  end)

  it("includes descendants when mid-stack (whole stack)", function()
    local nodes = walk.walk(by, "feat-a")
    assert.same({ "feat-a", "feat-b", "feat-c" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
  end)

  it("flattens forks depth-first with sorted siblings", function()
    local forked = {
      ["feat-a"] = row("feat-a", "main", "aaa111", "000aaa"),
      ["feat-b"] = row("feat-b", "feat-a", "bbb222", "aaa111"),
      ["feat-c"] = row("feat-c", "feat-b", "ccc333", "bbb222"),
      ["feat-b2"] = row("feat-b2", "feat-a", "eee555", "aaa111"),
    }
    local nodes = walk.walk(forked, "feat-a")
    assert.same({ "feat-a", "feat-b", "feat-c", "feat-b2" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
  end)

  it("does not treat unrelated stacks as descendants", function()
    local nodes = walk.walk(by, "feat-b")
    for _, n in ipairs(nodes) do
      assert.not_equals("unrelated", n.id)
    end
  end)

  it("excludes trunk's own row (empty parent)", function()
    -- A trunk row with an empty parent must not become a changeset with an
    -- empty base ref.
    local with_trunk = {
      develop = row("develop", ""),
      feat = row("feat", "develop", "fff111", "ddd000"),
    }
    local nodes = walk.walk(with_trunk, "feat")
    assert.same({ "feat" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
    local none = walk.walk(with_trunk, "develop")
    assert.same({}, none)
  end)

  it("returns empty when the focus branch has no row", function()
    assert.same({}, walk.walk(by, "main"))
  end)

  it("guards against parent cycles", function()
    local cyclic = {
      x = row("x", "y", "1", "2"),
      y = row("y", "x", "3", "4"),
    }
    local nodes = walk.walk(cyclic, "x")
    assert.equals(2, #nodes)
  end)

  it("falls back to branch name / parent when revisions are empty", function()
    local sparse = { feat = row("feat", "main") }
    local nodes = walk.walk(sparse, "feat")
    assert.equals("feat", nodes[1].head_rev)
    assert.equals("main", nodes[1].parent_rev)
  end)
end)
