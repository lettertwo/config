local assert = require("luassert")
local ref = require("app.review.source.ref")

describe("ref source (temp repo)", function()
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

    -- Dirty worktree file: proves the ref source never surfaces it, except
    -- via the stack delegate when the token is the checked-out branch.
    vim.fn.writefile({ "base dirty" }, cwd .. "/base.lua")

    return cwd, run, main_sha, a_sha, b_sha
  end

  local function load(source)
    local changesets, err
    source:load(function(cs, e)
      changesets, err = cs, e
    end)
    vim.wait(10000, function()
      return changesets ~= nil or err ~= nil
    end, 50)
    return changesets, err
  end

  it("a single commit-ish: one changeset diffing <ref>^..<ref>", function()
    local cwd, _, _, a_sha, b_sha = make_repo()
    local src = ref.new({ cwd = cwd, classified = { kind = "ref", shape = "single", ref = b_sha } })
    assert.is_false(src:can_stage())
    assert.equals("flat", src.default_outline_mode)
    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.equals(b_sha, changesets[1].head_ref)
    assert.equals(a_sha, changesets[1].base_ref)
    assert.is_true(changesets[1].current)
    assert.same({ "b.lua" }, vim.tbl_map(function(f)
      return f.path
    end, changesets[1].files))
    for _, f in ipairs(changesets[1].files) do
      assert.are_not.equal("WORKTREE", f.head_ref)
    end
  end)

  it("a branch token delegates to the stack source, focused there", function()
    local cwd = make_repo() -- checked out on "feature"
    local src = ref.new({ cwd = cwd, classified = { kind = "ref", shape = "single", ref = "feature" } })
    local changesets, err = load(src)
    assert.is_nil(err)
    -- Identical to the bare :Review shape from that branch: the git-log
    -- fallback's per-commit nodes plus the dirty worktree file, since
    -- "feature" is also the checked-out branch here.
    assert.is_true(src:can_stage())
    local ids = vim.tbl_map(function(cs)
      return cs.id
    end, changesets)
    assert.truthy(vim.tbl_contains(ids, "uncommitted"))
  end)

  it("a two-dot range: one changeset over the endpoint trees", function()
    local cwd, _, main_sha, a_sha, b_sha = make_repo()
    local src = ref.new({
      cwd = cwd,
      classified = { kind = "ref", shape = "range", dots = 2, base = "main", head = "feature" },
    })
    assert.equals("flat", src.default_outline_mode)
    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.equals(main_sha, changesets[1].base_ref)
    assert.equals(b_sha, changesets[1].head_ref)
    assert.is_true(changesets[1].current)
    assert.same({ "a.lua", "b.lua" }, vim.tbl_map(function(f)
      return f.path
    end, changesets[1].files))
    for _, f in ipairs(changesets[1].files) do
      assert.are_not.equal("WORKTREE", f.head_ref)
    end
  end)

  it("a three-dot range diffs from the merge-base, ignoring the base side's own advances", function()
    local cwd, run, main_sha, _, b_sha = make_repo()
    run("checkout", "-q", "main")
    vim.fn.writefile({ "c" }, cwd .. "/c.lua")
    run("add", "c.lua")
    run("commit", "-qm", "add c on main")

    local two_dot = ref.new({
      cwd = cwd,
      classified = { kind = "ref", shape = "range", dots = 2, base = "main", head = "feature" },
    })
    local two_dot_cs = load(two_dot)
    local two_dot_paths = vim.tbl_map(function(f)
      return f.path
    end, two_dot_cs[1].files)
    table.sort(two_dot_paths)
    -- Tree-to-tree: c.lua shows up as removed on the feature side too.
    assert.same({ "a.lua", "b.lua", "c.lua" }, two_dot_paths)

    local three_dot = ref.new({
      cwd = cwd,
      classified = { kind = "ref", shape = "range", dots = 3, base = "main", head = "feature" },
    })
    local three_dot_cs, err = load(three_dot)
    assert.is_nil(err)
    assert.equals(main_sha, three_dot_cs[1].base_ref)
    assert.equals(b_sha, three_dot_cs[1].head_ref)
    assert.same({ "a.lua", "b.lua" }, vim.tbl_map(function(f)
      return f.path
    end, three_dot_cs[1].files))
  end)

  it("root-commit single ref: empty-tree base, status A files", function()
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
    vim.fn.writefile({ "root" }, cwd .. "/root.lua")
    run("add", ".")
    run("commit", "-qm", "root commit")

    local src = ref.new({ cwd = cwd, classified = { kind = "ref", shape = "single", ref = "HEAD" } })
    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.equals(1, #changesets[1].files)
    assert.equals("A", changesets[1].files[1].status)
  end)

  it("invalid ref surfaces an error", function()
    local cwd = make_repo()
    local src = ref.new({ cwd = cwd, classified = { kind = "ref", shape = "single", ref = "nosuchref" } })
    local changesets, err = load(src)
    assert.is_nil(changesets)
    assert.is_string(err)
  end)

  it("an equal-endpoint range produces one empty changeset without crashing", function()
    local cwd = make_repo()
    local src = ref.new({
      cwd = cwd,
      classified = { kind = "ref", shape = "range", dots = 2, base = "feature", head = "feature" },
    })
    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.same({}, changesets[1].files)
  end)
end)
