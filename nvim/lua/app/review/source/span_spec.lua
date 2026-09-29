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

describe("span.build_commits (temp repo)", function()
  local git = require("app.review.diff.git")

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
    vim.fn.writefile({ "b" }, cwd .. "/b.lua")
    run("add", ".")
    run("commit", "-qm", "add b")
    return cwd, main_sha, run("rev-parse", "HEAD")
  end

  -- Collect every snapshot; settled means no Pending slot.
  local function collect(cwd, base, head)
    local snapshots, err = {}, nil
    span.build_commits(cwd, base, head, nil, function(cs, e)
      if e then
        err = e
      else
        table.insert(snapshots, cs)
      end
    end)
    local function last_settled()
      local cs = snapshots[#snapshots]
      if not cs then
        return false
      end
      for _, c in ipairs(cs) do
        if c.status == "pending" then
          return false
        end
      end
      return true
    end
    vim.wait(10000, function()
      return err ~= nil or last_settled()
    end, 50)
    return snapshots, err
  end

  it("streams a Pending skeleton, then one changeset per commit, oldest first, newest current", function()
    local cwd, main_sha, head_sha = make_repo()
    local snapshots, err = collect(cwd, main_sha, head_sha)
    assert.is_nil(err)
    assert.equals("pending", snapshots[1][1].status)
    assert.is_true(snapshots[1][2].current)
    local final = snapshots[#snapshots]
    assert.same({ "add a", "add b" }, vim.tbl_map(function(c)
      return c.title
    end, final))
    assert.same({ "a.lua" }, vim.tbl_map(function(f)
      return f.path
    end, final[1].files))
    assert.same({ "b.lua" }, vim.tbl_map(function(f)
      return f.path
    end, final[2].files))
    assert.equals(head_sha, final[2].head_ref)
    assert.is_true(final[2].current)
  end)

  it("diffs each commit against its own parent, and the root commit against the empty tree", function()
    local cwd, _, head_sha = make_repo()
    local root = vim.trim(vim.system({ "git", "rev-list", "--max-parents=0", "HEAD" }, { cwd = cwd, text = true }):wait().stdout)
    local empty
    git.empty_tree(cwd, function(sha)
      empty = sha
    end)
    vim.wait(5000, function()
      return empty ~= nil
    end, 20)
    local snapshots, err = collect(cwd, empty, head_sha)
    assert.is_nil(err)
    local final = snapshots[#snapshots]
    assert.equals(3, #final)
    assert.equals(empty, final[1].base_ref)
    assert.equals(root, final[1].head_ref)
    assert.equals(root, final[2].base_ref)
  end)

  it("keeps a commit whose diff fails as a Failed changeset instead of failing the build", function()
    local cwd, main_sha, head_sha = make_repo()
    local real_diff = git.diff
    git.diff = function(c, base, head, cb)
      if head == head_sha then
        cb(nil, "boom")
      else
        real_diff(c, base, head, cb)
      end
    end
    local snapshots, err = collect(cwd, main_sha, head_sha)
    git.diff = real_diff
    assert.is_nil(err)
    local final = snapshots[#snapshots]
    assert.equals("ready", final[1].status)
    assert.equals("failed", final[2].status)
    assert.equals("boom", final[2].error)
  end)

  it("reports a failed git log as an error", function()
    local cwd = make_repo()
    local snapshots, err = collect(cwd, "nosuchref", "feature")
    assert.same({}, snapshots)
    assert.is_string(err)
  end)
end)
