local assert = require("luassert")

-- Integration: stack source over a real repo with a fabricated graphite db,
-- from a mid-stack position. Covers whole-stack scope (descendants included),
-- uncommitted placement (adjacent to the current branch, not stack-first),
-- the current-position marker, and the needs-restack flag.
describe("stack source (mid-stack, graphite)", function()
  if vim.fn.executable("sqlite3") == 0 then
    return -- graphite path is sqlite3-gated
  end

  local cwd = vim.fn.tempname()
  vim.fn.mkdir(cwd, "p")
  local function run(...)
    local r = vim.system({ ... }, { cwd = cwd, text = true }):wait()
    assert.equals(0, r.code, r.stderr)
    return vim.trim(r.stdout or "")
  end
  run("git", "init", "-q")
  run("git", "branch", "-M", "main")
  run("git", "config", "user.email", "t@t")
  run("git", "config", "user.name", "t")
  vim.fn.writefile({ "base" }, cwd .. "/base.txt")
  run("git", "add", ".")
  run("git", "commit", "-qm", "init")
  local main_sha = run("git", "rev-parse", "HEAD")

  run("git", "checkout", "-qb", "feat-a")
  vim.fn.writefile({ "a" }, cwd .. "/a.txt")
  run("git", "add", ".")
  run("git", "commit", "-qm", "feat a")
  local a_sha = run("git", "rev-parse", "HEAD")

  run("git", "checkout", "-qb", "feat-b")
  vim.fn.writefile({ "b" }, cwd .. "/b.txt")
  run("git", "add", ".")
  run("git", "commit", "-qm", "feat b")
  local b_sha = run("git", "rev-parse", "HEAD")

  -- Sit mid-stack on feat-a with an uncommitted (untracked) file.
  run("git", "checkout", "-q", "feat-a")
  vim.fn.writefile({ "dirty" }, cwd .. "/dirty.txt")

  -- feat-b's recorded parent_rev is main's sha, NOT feat-a's head → it is
  -- pending a restack.
  run(
    "sqlite3",
    cwd .. "/.git/.graphite_metadata.db",
    "CREATE TABLE branch_metadata (branch_name TEXT, parent_branch_name TEXT,"
      .. " branch_revision TEXT, parent_branch_revision TEXT);"
      .. (" INSERT INTO branch_metadata VALUES ('feat-a','main','%s','%s');"):format(a_sha, main_sha)
      .. (" INSERT INTO branch_metadata VALUES ('feat-b','feat-a','%s','%s');"):format(b_sha, main_sha)
  )

  -- The source streams: this snapshot fires once per changeset that settles,
  -- so a bare "changesets ~= nil" would stop the wait on the first (mostly
  -- Pending) skeleton. Wait for the shape this scenario's assertions need:
  -- three changesets, none still fetching, and the restack flag (the last
  -- thing to land, off its own rev-parse) applied.
  local function settled(cs)
    if #cs ~= 3 then
      return false
    end
    for _, c in ipairs(cs) do
      if c.status == "pending" then
        return false
      end
    end
    return cs[3].title:find("needs restack", 1, true) ~= nil
  end

  local changesets, err
  require("app.review.source.stack").new({ cwd = cwd }):load(function(cs, e)
    changesets, err = cs, e
  end)
  vim.wait(10000, function()
    return err ~= nil or (changesets ~= nil and settled(changesets))
  end, 50)

  it("loads without error", function()
    assert.is_nil(err)
    assert.is_table(changesets)
  end)

  it("orders ancestors, current, uncommitted, then descendants", function()
    assert.same(
      { "feat-a", "uncommitted", "feat-b" },
      vim.tbl_map(function(cs)
        return cs.id
      end, changesets)
    )
  end)

  it("marks the uncommitted changeset as the session's starting position", function()
    assert.is_true(changesets[2].current)
    assert.is_nil(changesets[1].current)
    assert.is_nil(changesets[3].current)
  end)

  it("flags stale descendants as needing a restack", function()
    assert.truthy(changesets[3].title:find("needs restack", 1, true))
    assert.is_nil(changesets[1].title:find("needs restack", 1, true))
  end)

  it("keeps per-changeset diffs commit-ranged", function()
    assert.same({ "a.txt" }, vim.tbl_map(function(f)
      return f.path
    end, changesets[1].files))
    assert.equals("dirty.txt", changesets[2].files[1].path)
  end)
end)

-- The shared changeset builder underneath the stack source: which specs it
-- re-diffs across a rebuild, and the order it issues the diffs it does run.
describe("changesets.build", function()
  local changesets = require("app.review.source.changesets")
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
    vim.fn.writefile({ "base" }, cwd .. "/base.txt")
    run("add", ".")
    run("commit", "-qm", "init")
    return cwd, run
  end

  -- Runs `changesets.build` to completion (no slot left Pending) and returns
  -- its last snapshot.
  local function build(cwd, specs, prev)
    local result
    changesets.build(cwd, specs, prev, function(r)
      result = r
    end)
    vim.wait(10000, function()
      if not result then
        return false
      end
      for _, cs in ipairs(result) do
        if cs.status == "pending" then
          return false
        end
      end
      return true
    end, 20)
    return result
  end

  it("reuses a Ready changeset outright when its resolved shas didn't move", function()
    local cwd, run = make_repo()
    run("checkout", "-qb", "feature")
    vim.fn.writefile({ "a" }, cwd .. "/a.txt")
    run("add", ".")
    run("commit", "-qm", "add a")
    local head_sha = run("rev-parse", "HEAD")

    local specs = { { id = "a", title = "a", base = "main", head = head_sha } }
    local prev = build(cwd, specs, nil)
    assert.equals("ready", prev[1].status)

    local calls = 0
    local orig_diff = git.diff
    git.diff = function(...)
      calls = calls + 1
      orig_diff(...)
    end
    local result = build(cwd, specs, prev)
    git.diff = orig_diff

    assert.equals(0, calls)
    assert.equal(prev[1], result[1])
  end)

  it("re-diffs a spec whose resolved head sha moved since the reused changeset", function()
    local cwd, run = make_repo()
    run("checkout", "-qb", "feature")
    vim.fn.writefile({ "a" }, cwd .. "/a.txt")
    run("add", ".")
    run("commit", "-qm", "add a")

    local specs = { { id = "a", title = "a", base = "main", head = "feature" } }
    local prev = build(cwd, specs, nil)
    assert.equals("ready", prev[1].status)
    assert.same({ "a.txt" }, vim.tbl_map(function(f)
      return f.path
    end, prev[1].files))

    -- A new commit on the branch resolves "feature" to a different sha; the
    -- spec itself is unchanged (same ref text), but the reuse key isn't.
    vim.fn.writefile({ "b" }, cwd .. "/b.txt")
    run("add", ".")
    run("commit", "-qm", "add b")

    local calls = 0
    local orig_diff = git.diff
    git.diff = function(...)
      calls = calls + 1
      orig_diff(...)
    end
    local result = build(cwd, specs, prev)
    git.diff = orig_diff

    assert.equals(1, calls)
    assert.are_not.equal(prev[1], result[1])
    assert.same({ "a.txt", "b.txt" }, vim.tbl_map(function(f)
      return f.path
    end, result[1].files))
  end)

  it("issues the current spec's diff before its siblings, siblings in spec order", function()
    local cwd, run = make_repo()
    local main_sha = run("rev-parse", "HEAD")
    vim.fn.writefile({ "a" }, cwd .. "/a.txt")
    run("add", ".")
    run("commit", "-qm", "commit a")
    local a_sha = run("rev-parse", "HEAD")
    vim.fn.writefile({ "b" }, cwd .. "/b.txt")
    run("add", ".")
    run("commit", "-qm", "commit b")
    local b_sha = run("rev-parse", "HEAD")
    vim.fn.writefile({ "c" }, cwd .. "/c.txt")
    run("add", ".")
    run("commit", "-qm", "commit c")
    local c_sha = run("rev-parse", "HEAD")

    local specs = {
      { id = "a", title = "a", base = main_sha, head = a_sha },
      { id = "b", title = "b", base = a_sha, head = b_sha, current = true },
      { id = "c", title = "c", base = b_sha, head = c_sha },
    }

    local calls = {}
    local orig_diff = git.diff
    git.diff = function(cwd_, base, head, cb)
      table.insert(calls, { base = base, head = head })
      orig_diff(cwd_, base, head, cb)
    end
    build(cwd, specs, nil)
    git.diff = orig_diff

    assert.same({
      { base = a_sha, head = b_sha }, -- current spec first
      { base = main_sha, head = a_sha }, -- then the rest, in spec order
      { base = b_sha, head = c_sha },
    }, calls)
  end)
end)
