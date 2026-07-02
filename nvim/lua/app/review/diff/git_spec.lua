local assert = require("luassert")
local git = require("app.review.diff.git")

describe("git.common_dir_sync", function()
  -- One fixture: a plain repo plus a linked worktree of it.
  local main = vim.fn.tempname()
  vim.fn.mkdir(main, "p")
  local function run(...)
    local r = vim.system({ "git", ... }, { cwd = main, text = true }):wait()
    assert.equals(0, r.code, r.stderr)
  end
  run("init", "-q")
  run("config", "user.email", "t@t")
  run("config", "user.name", "t")
  vim.fn.writefile({ "x" }, main .. "/f")
  run("add", ".")
  run("commit", "-qm", "init")
  local wt = vim.fn.tempname()
  run("worktree", "add", "-q", "-b", "side", wt)

  it("resolves the plain repo's own .git (relative output normalized)", function()
    assert.equals(main .. "/.git", git.common_dir_sync(main))
  end)

  it("resolves a linked worktree to the shared common dir", function()
    -- cwd/.git is a FILE here; repo-wide state (graphite metadata) lives in
    -- the common dir, which must resolve back to the main repo's .git.
    assert.equals(1, vim.fn.filereadable(wt .. "/.git"))
    local common = git.common_dir_sync(wt)
    assert.is_string(common)
    -- resolve() both sides: worktree git dirs can come back via symlinked tmp paths
    assert.equals(vim.fn.resolve(main .. "/.git"), vim.fn.resolve(common))
  end)

  it("returns nil outside a repo", function()
    assert.is_nil(git.common_dir_sync(vim.fn.tempname()))
  end)
end)
