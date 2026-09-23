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
