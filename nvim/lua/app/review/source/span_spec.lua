local assert = require("luassert")
local span = require("app.review.source.span")

describe("span.build (temp repo)", function()
  local function make_repo()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function run(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
      return vim.trim(r.stdout or "")
    end
    run("init", "-q")
    run("branch", "-M", "main")
    run("config", "user.email", "t@t")
    run("config", "user.name", "t")
    vim.fn.writefile({ "base" }, cwd .. "/base.lua")
    run("add", ".")
    run("commit", "-qm", "init")
    local main_sha = run("rev-parse", "HEAD")

    run("checkout", "-qb", "feature")
    vim.fn.writefile({ "a" }, cwd .. "/a.lua")
    run("add", ".")
    run("commit", "-qm", "add a")
    local a_sha = run("rev-parse", "HEAD")

    vim.fn.writefile({ "b" }, cwd .. "/b.lua")
    run("add", ".")
    run("commit", "-qm", "add b")
    local b_sha = run("rev-parse", "HEAD")

    -- Dirty worktree file: proves a span never surfaces it.
    vim.fn.writefile({ "base dirty" }, cwd .. "/base.lua")

    return cwd, run, main_sha, a_sha, b_sha
  end

  local function build(cwd, base, head, title)
    local changesets, err
    span.build(cwd, base, head, title, function(cs, e)
      changesets, err = cs, e
    end)
    vim.wait(10000, function()
      return changesets ~= nil or err ~= nil
    end, 50)
    return changesets, err
  end

  it("produces one changeset over the endpoint trees", function()
    local cwd, _, main_sha, _, b_sha = make_repo()
    local changesets, err = build(cwd, "main", "feature", "main..feature")
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.equals(main_sha, changesets[1].base_ref)
    assert.equals(b_sha, changesets[1].head_ref)
    assert.same({ "a.lua", "b.lua" }, vim.tbl_map(function(f)
      return f.path
    end, changesets[1].files))
    for _, f in ipairs(changesets[1].files) do
      assert.are_not.equal("WORKTREE", f.head_ref)
    end
  end)

  it("collapses an equal endpoint pair to one empty changeset", function()
    local cwd = make_repo()
    local changesets, err = build(cwd, "feature", "feature", "feature..feature")
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.same({}, changesets[1].files)
  end)

  it("surfaces an unresolvable endpoint as an error", function()
    local cwd = make_repo()
    local changesets, err = build(cwd, "nosuchref", "feature", "nosuchref..feature")
    assert.is_nil(changesets)
    assert.is_string(err)
  end)

  it("carries the given title", function()
    local cwd = make_repo()
    local changesets = build(cwd, "main", "feature", "custom title")
    assert.equals("custom title", changesets[1].title)
  end)
end)
