local assert = require("luassert")
local factory = require("app.review.source.graph")

-- A graphite metadata db can exist while telling us nothing about the current
-- branch (vestigial db, or a branch never tracked by gt). The factory must
-- fall back to the git graph instead of yielding an empty stack.
describe("graph factory fallback", function()
  local has_sqlite = vim.fn.executable("sqlite3") == 1

  local function make_repo()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function run(...)
      local r = vim.system({ ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
    end
    run("git", "init", "-q")
    run("git", "config", "user.email", "t@t")
    run("git", "config", "user.name", "t")
    vim.fn.writefile({ "x" }, cwd .. "/f")
    run("git", "add", ".")
    run("git", "commit", "-qm", "init")
    return cwd, run
  end

  it("uses the git graph when there is no graphite db", function()
    local cwd = make_repo()
    local g = factory.create(cwd)
    assert.is_function(g.load) -- git fallback is the async graph
  end)

  it("falls back to the git graph when the graphite walk is empty", function()
    if not has_sqlite then
      return -- factory can't take the graphite path without sqlite3 anyway
    end
    local cwd, run = make_repo()
    -- Vestigial db: table exists, no rows for any branch.
    run(
      "sqlite3",
      cwd .. "/.git/.graphite_metadata.db",
      "CREATE TABLE branch_metadata (branch_name TEXT, parent_branch_name TEXT,"
        .. " branch_revision TEXT, parent_branch_revision TEXT);"
    )
    local g = factory.create(cwd)
    assert.is_function(g.load)
  end)

  it("uses graphite when the walk yields nodes for the current branch", function()
    if not has_sqlite then
      return
    end
    local cwd, run = make_repo()
    run("git", "checkout", "-qb", "feat")
    run(
      "sqlite3",
      cwd .. "/.git/.graphite_metadata.db",
      "CREATE TABLE branch_metadata (branch_name TEXT, parent_branch_name TEXT,"
        .. " branch_revision TEXT, parent_branch_revision TEXT);"
        .. " INSERT INTO branch_metadata VALUES ('feat','main','','');"
    )
    local g = factory.create(cwd)
    assert.is_nil(g.load) -- graphite graph is synchronous
    assert.equals(1, #g:nodes())
  end)
end)
