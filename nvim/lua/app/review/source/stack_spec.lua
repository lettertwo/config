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

  local changesets, err
  require("app.review.source.stack").new({ cwd = cwd }):load(function(cs, e)
    changesets, err = cs, e
  end)
  vim.wait(10000, function()
    return changesets ~= nil or err ~= nil
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
