local assert = require("luassert")
local graphite = require("app.review.source.graph.graphite")

describe("graphite._parse_metadata", function()
  it("parses |-separated sqlite output into a by-branch map", function()
    local by = graphite._parse_metadata(table.concat({
      "feat-a|main|aaa111|000aaa",
      "feat-b|feat-a|bbb222|aaa111",
    }, "\n"))
    assert.same({
      branch = "feat-a",
      parent = "main",
      head_rev = "aaa111",
      parent_rev = "000aaa",
    }, by["feat-a"])
    assert.same("feat-a", by["feat-b"].parent)
  end)

  it("skips malformed lines", function()
    local by = graphite._parse_metadata("just-one-field\nok|main||\n")
    assert.is_nil(by["just-one-field"])
    assert.is_table(by["ok"])
  end)

  it("returns empty for empty output", function()
    assert.same({}, graphite._parse_metadata(""))
  end)
end)

describe("graphite._walk", function()
  local by = graphite._parse_metadata(table.concat({
    "feat-a|main|aaa111|000aaa",
    "feat-b|feat-a|bbb222|aaa111",
    "feat-c|feat-b|ccc333|bbb222",
    "unrelated|main|ddd444|000aaa",
  }, "\n"))

  it("walks parents from the current branch in base→head order", function()
    local nodes = graphite._walk(by, "feat-c")
    assert.same({ "feat-a", "feat-b", "feat-c" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
    assert.equals("000aaa", nodes[1].parent_rev)
    assert.equals("ccc333", nodes[3].head_rev)
  end)

  it("includes descendants when mid-stack (whole stack)", function()
    local nodes = graphite._walk(by, "feat-a")
    assert.same({ "feat-a", "feat-b", "feat-c" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
  end)

  it("flattens forks depth-first with sorted siblings", function()
    local forked = graphite._parse_metadata(table.concat({
      "feat-a|main|aaa111|000aaa",
      "feat-b|feat-a|bbb222|aaa111",
      "feat-c|feat-b|ccc333|bbb222",
      "feat-b2|feat-a|eee555|aaa111",
    }, "\n"))
    local nodes = graphite._walk(forked, "feat-a")
    assert.same({ "feat-a", "feat-b", "feat-c", "feat-b2" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
  end)

  it("does not treat unrelated stacks as descendants", function()
    local nodes = graphite._walk(by, "feat-b")
    for _, n in ipairs(nodes) do
      assert.not_equals("unrelated", n.id)
    end
  end)

  it("excludes trunk's own metadata row (empty parent)", function()
    -- Real graphite DBs give trunk a row with an empty parent_branch_name;
    -- trunk must not become a changeset with an empty base ref.
    local with_trunk = graphite._parse_metadata(table.concat({
      "develop|",
      "feat|develop|fff111|ddd000",
    }, "\n"))
    local nodes = graphite._walk(with_trunk, "feat")
    assert.same({ "feat" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
    local none = graphite._walk(with_trunk, "develop")
    assert.same({}, none)
  end)

  it("returns empty when the current branch has no metadata", function()
    assert.same({}, graphite._walk(by, "main"))
  end)

  it("guards against parent cycles", function()
    local cyclic = graphite._parse_metadata("x|y|1|2\ny|x|3|4\n")
    local nodes = graphite._walk(cyclic, "x")
    assert.equals(2, #nodes)
  end)

  it("falls back to branch name / parent when revisions are empty", function()
    local sparse = graphite._parse_metadata("feat|main||\n")
    local nodes = graphite._walk(sparse, "feat")
    assert.equals("feat", nodes[1].head_rev)
    assert.equals("main", nodes[1].parent_rev)
  end)
end)
