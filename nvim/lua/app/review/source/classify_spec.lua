local assert = require("luassert")
local classify = require("app.review.source.classify").classify

describe("classify: keywords", function()
  it("bare argument is stack", function()
    assert.same({ kind = "stack" }, classify(nil))
    assert.same({ kind = "stack" }, classify(""))
    assert.same({ kind = "stack" }, classify("   "))
  end)

  it("the stack keyword is stack", function()
    assert.same({ kind = "stack" }, classify("stack"))
  end)

  it("the uncommitted keyword is uncommitted", function()
    assert.same({ kind = "uncommitted" }, classify("uncommitted"))
  end)
end)

describe("classify: PR spellings", function()
  it("#N", function()
    assert.same({ kind = "pr", number = 42 }, classify("#42"))
  end)

  it("pr-N", function()
    assert.same({ kind = "pr", number = 7 }, classify("pr-7"))
  end)

  it("pr#N", function()
    assert.same({ kind = "pr", number = 7 }, classify("pr#7"))
  end)

  it("a GitHub pull URL, repo-scoped", function()
    assert.same(
      { kind = "pr", number = 99, repo = "acme/widgets" },
      classify("https://github.com/acme/widgets/pull/99")
    )
  end)

  it("a GitHub pull URL with a trailing slash", function()
    assert.same(
      { kind = "pr", number = 99, repo = "acme/widgets" },
      classify("https://github.com/acme/widgets/pull/99/")
    )
  end)

  it("a bare number is a ref, never a PR", function()
    assert.same({ kind = "ref", shape = "single", ref = "123" }, classify("123"))
  end)

  it("rejects a malformed pr- spelling with no digits", function()
    local result, err = classify("pr-")
    assert.is_nil(result)
    assert.is_string(err)
  end)

  it("rejects a malformed pr- spelling with non-numeric digits", function()
    local result, err = classify("pr-abc")
    assert.is_nil(result)
    assert.is_string(err)
  end)

  it("rejects a malformed # spelling", function()
    local result, err = classify("#abc")
    assert.is_nil(result)
    assert.is_string(err)
  end)
end)

describe("classify: ranges", function()
  it("a..b is a two-dot range", function()
    assert.same(
      { kind = "ref", shape = "range", dots = 2, base = "main", head = "feature" },
      classify("main..feature")
    )
  end)

  it("a...b is a three-dot range", function()
    assert.same(
      { kind = "ref", shape = "range", dots = 3, base = "main", head = "feature" },
      classify("main...feature")
    )
  end)

  it("defaults an empty two-dot side to HEAD", function()
    assert.same({ kind = "ref", shape = "range", dots = 2, base = "main", head = "HEAD" }, classify("main.."))
    assert.same({ kind = "ref", shape = "range", dots = 2, base = "HEAD", head = "feature" }, classify("..feature"))
  end)

  it("defaults an empty three-dot side to HEAD", function()
    assert.same({ kind = "ref", shape = "range", dots = 3, base = "main", head = "HEAD" }, classify("main..."))
    assert.same({ kind = "ref", shape = "range", dots = 3, base = "HEAD", head = "feature" }, classify("...feature"))
  end)
end)

describe("classify: bare refs", function()
  it("a branch or commit-ish is a single ref, shape resolved later", function()
    assert.same({ kind = "ref", shape = "single", ref = "feature" }, classify("feature"))
    assert.same({ kind = "ref", shape = "single", ref = "abc1234" }, classify("abc1234"))
  end)

  it("a branch named after a keyword is not reachable by that spelling", function()
    -- Documented precedence: keywords always win, so a branch literally
    -- named "stack" must be addressed by its full ref form elsewhere.
    assert.same({ kind = "stack" }, classify("stack"))
  end)
end)
