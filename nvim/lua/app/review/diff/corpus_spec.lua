local assert = require("luassert")
local parser = require("app.review.diff.parser")

-- End-state trap corpus for parser.hunk_to_patch: index/worktree bytes and
-- file mode after a real `git apply`, not just patch-text shape or a
-- `--check` dry run.
describe("parser.hunk_to_patch: end-state bytes", function()
  local function read_bytes(path)
    local fh = assert(io.open(path, "rb"))
    local data = fh:read("*a")
    fh:close()
    return data
  end

  local function git_show(cwd, path)
    local r = vim.system({ "git", "show", ":" .. path }, { cwd = cwd, text = true }):wait()
    assert.equals(0, r.code, r.stderr)
    return r.stdout
  end

  -- Byte-precise repo fixture: writefile's "b" mode leaves trailing-newline
  -- state exact, unlike parser_spec.lua's make_repo, which always appends one.
  local function repo_bytes(path, setup, mutate)
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function git(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
    end
    git("init", "-q")
    git("config", "user.email", "t@t")
    git("config", "user.name", "t")
    vim.fn.writefile(setup, cwd .. "/" .. path, "b")
    git("add", ".")
    git("commit", "-qm", "init")
    vim.fn.writefile(mutate, cwd .. "/" .. path, "b")
    local r = vim.system(
      { "git", "diff", "--no-color", "--unified=3", "HEAD" },
      { cwd = cwd, text = true }
    ):wait()
    return cwd, parser.parse(r.stdout)
  end

  it("stages a dropped trailing newline exactly: no trailing byte in the index", function()
    local cwd, files = repo_bytes("f.lua", { "line1", "line2", "line3", "" }, { "line1", "line2", "line3" })
    local patch = parser.hunk_to_patch(files[1], files[1].hunks[1])
    local ar = vim.system({ "git", "apply", "--cached", "-" }, { cwd = cwd, text = true, stdin = patch }):wait()
    assert.equals(0, ar.code, ar.stderr)
    assert.equals("line1\nline2\nline3", git_show(cwd, "f.lua"))
  end)

  it("unstages a dropped trailing newline exactly: the index blob regains it", function()
    local cwd, files = repo_bytes("f.lua", { "line1", "line2", "line3", "" }, { "line1", "line2", "line3" })
    local r = vim.system({ "git", "add", "." }, { cwd = cwd, text = true }):wait()
    assert.equals(0, r.code, r.stderr)
    r = vim.system({ "git", "diff", "--no-color", "--cached", "HEAD" }, { cwd = cwd, text = true }):wait()
    files = parser.parse(r.stdout)
    local patch = parser.hunk_to_patch(files[1], files[1].hunks[1])
    local ar = vim.system(
      { "git", "apply", "--cached", "--reverse", "-" },
      { cwd = cwd, text = true, stdin = patch }
    ):wait()
    assert.equals(0, ar.code, ar.stderr)
    assert.equals("line1\nline2\nline3\n", git_show(cwd, "f.lua"))
  end)

  it("discards a dropped trailing newline exactly: the worktree file regains it", function()
    local cwd, files = repo_bytes("f.lua", { "line1", "line2", "line3", "" }, { "line1", "line2", "line3" })
    local patch = parser.hunk_to_patch(files[1], files[1].hunks[1])
    local ar = vim.system(
      { "git", "apply", "--reverse", "-" },
      { cwd = cwd, text = true, stdin = patch }
    ):wait()
    assert.equals(0, ar.code, ar.stderr)
    assert.equals("line1\nline2\nline3\n", read_bytes(cwd .. "/f.lua"))
  end)

  it("reconstructs a header for a path containing a space", function()
    local cwd, files = repo_bytes("my file.lua", { "a", "b", "c", "" }, { "a", "B", "c", "" })
    local patch = parser.hunk_to_patch(files[1], files[1].hunks[1])
    local ar = vim.system({ "git", "apply", "--cached", "-" }, { cwd = cwd, text = true, stdin = patch }):wait()
    assert.equals(0, ar.code, ar.stderr)
    assert.equals("a\nB\nc\n", git_show(cwd, "my file.lua"))
  end)

  -- Known bug: parser.parse skips old mode/new mode header lines, and
  -- hunk_to_patch has nothing to re-emit them from, so a chmod-plus-content
  -- hunk stages the content and silently drops the bit. Flip to `it` once
  -- hunk_to_patch carries the mode headers.
  pending("stages the executable bit alongside a content change in one hunk", function()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function git(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
    end
    git("init", "-q")
    git("config", "user.email", "t@t")
    git("config", "user.name", "t")
    vim.fn.writefile({ "echo committed" }, cwd .. "/run.sh")
    vim.uv.fs_chmod(cwd .. "/run.sh", 420) -- 0644
    git("add", ".")
    git("commit", "-qm", "init")
    vim.fn.writefile({ "echo modified" }, cwd .. "/run.sh")
    vim.uv.fs_chmod(cwd .. "/run.sh", 493) -- 0755
    local r = vim.system(
      { "git", "diff", "--no-color", "--unified=3", "HEAD" },
      { cwd = cwd, text = true }
    ):wait()
    local files = parser.parse(r.stdout)

    local patch = parser.hunk_to_patch(files[1], files[1].hunks[1])
    local ar = vim.system({ "git", "apply", "--cached", "-" }, { cwd = cwd, text = true, stdin = patch }):wait()
    assert.equals(0, ar.code, ar.stderr)
    local ls = vim.system({ "git", "ls-files", "--stage", "run.sh" }, { cwd = cwd, text = true }):wait()
    assert.truthy(ls.stdout:match("^100755"), ls.stdout)
  end)
end)
