local assert = require("luassert")
local graph_git = require("app.review.source.graph.git")

describe("graph.git._build_nodes", function()
  it("builds one node per commit, base→head, bases chained to next-older", function()
    -- git log returns newest-first
    local nodes = graph_git._build_nodes("main", "feat", {
      { sha = "ccc", subject = "third" },
      { sha = "bbb", subject = "second" },
      { sha = "aaa", subject = "first" },
    })
    assert.same({ "aaa", "bbb", "ccc" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
    assert.equals("main", nodes[1].parent_rev) -- oldest bases on trunk
    assert.equals("aaa", nodes[2].parent_rev)
    assert.equals("bbb", nodes[3].parent_rev)
    assert.equals("third", nodes[3].title)
  end)

  it("returns a degenerate HEAD node when on trunk", function()
    local nodes = graph_git._build_nodes("main", "main", nil)
    assert.equals(1, #nodes)
    assert.equals("HEAD", nodes[1].id)
    assert.equals("HEAD~1", nodes[1].parent_rev)
  end)

  it("treats the whole branch as one changeset when the log is empty", function()
    for _, commits in ipairs({ { nil }, { {} } }) do
      local nodes = graph_git._build_nodes("main", "feat", commits[1])
      assert.equals(1, #nodes)
      assert.equals("feat", nodes[1].id)
      assert.equals("main", nodes[1].parent_rev)
      assert.equals("feat", nodes[1].head_rev)
    end
  end)
end)
