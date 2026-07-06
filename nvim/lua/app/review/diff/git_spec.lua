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

describe("git staging primitives (real repo round-trips)", function()
  local parser = require("app.review.diff.parser")

  -- Repo with committed content and a worktree mutation; returns cwd.
  local function make_repo(committed, worktree)
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function run(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
      return r.stdout or ""
    end
    vim.fn.writefile(committed, cwd .. "/f.lua")
    run("init", "-q")
    run("config", "user.email", "t@t")
    run("config", "user.name", "t")
    run("add", ".")
    run("commit", "-qm", "init")
    vim.fn.writefile(worktree, cwd .. "/f.lua")
    return cwd, run
  end

  -- Await an async primitive; asserts success.
  local function await(fn)
    local done, got_err = false, nil
    fn(function(err)
      done, got_err = true, err
    end)
    vim.wait(4000, function()
      return done
    end, 10)
    assert.is_true(done, "primitive did not complete")
    return got_err
  end

  local function unstaged_hunk(cwd, run)
    local raw = run("diff", "--no-color", "--unified=3")
    local files = parser.parse(raw)
    assert.equals(1, #files)
    return files[1], files[1].hunks[1]
  end

  local lines = {}
  for i = 1, 12 do
    lines[i] = ("line %d"):format(i)
  end

  it("stage_path / unstage_path round-trip", function()
    local mutated = vim.deepcopy(lines)
    mutated[3] = "line 3 edited"
    local cwd, run = make_repo(lines, mutated)
    assert.is_nil(await(function(cb)
      git.stage_path(cwd, "f.lua", cb)
    end))
    assert.is_truthy(run("diff", "--cached"):match("line 3 edited"))
    assert.is_nil(await(function(cb)
      git.unstage_path(cwd, "f.lua", cb)
    end))
    assert.equals("", run("diff", "--cached"))
  end)

  it("apply_patch --cached stages a hunk, --reverse unstages it", function()
    local mutated = vim.deepcopy(lines)
    mutated[6] = "line 6 edited"
    local cwd, run = make_repo(lines, mutated)
    local file, hunk = unstaged_hunk(cwd, run)
    local patch = parser.hunk_to_patch(file, hunk)
    assert.is_nil(await(function(cb)
      git.apply_patch(cwd, patch, { cached = true }, cb)
    end))
    assert.is_truthy(run("diff", "--cached"):match("line 6 edited"))
    assert.is_nil(await(function(cb)
      git.apply_patch(cwd, patch, { cached = true, reverse = true }, cb)
    end))
    assert.equals("", run("diff", "--cached"))
  end)

  it("stages AND unstages a pure-deletion hunk (the POC corrupt-patch case)", function()
    local mutated = vim.deepcopy(lines)
    table.remove(mutated, 8)
    table.remove(mutated, 8) -- delete lines 8-9, no additions
    local cwd, run = make_repo(lines, mutated)
    local file, hunk = unstaged_hunk(cwd, run)
    assert.equals(0, #vim.tbl_filter(function(l)
      return l.kind == "add"
    end, hunk.lines))
    local patch = parser.hunk_to_patch(file, hunk)
    assert.is_nil(await(function(cb)
      git.apply_patch(cwd, patch, { cached = true }, cb)
    end))
    assert.is_truthy(run("diff", "--cached"):match("%-line 8"))
    assert.is_nil(await(function(cb)
      git.apply_patch(cwd, patch, { cached = true, reverse = true }, cb)
    end))
    assert.equals("", run("diff", "--cached"))
  end)

  it("apply_patch surfaces git's stderr on failure", function()
    local cwd = make_repo(lines, lines)
    local err = await(function(cb)
      git.apply_patch(cwd, "not a patch\n", { cached = true }, cb)
    end)
    assert.is_string(err)
  end)

  it("has_unstaged scopes to a pathspec", function()
    local cwd, run = make_repo(lines, lines)
    vim.fn.mkdir(cwd .. "/sub", "p")
    vim.fn.writefile({ "a" }, cwd .. "/sub/a.lua")
    vim.fn.writefile({ "b" }, cwd .. "/other.lua")
    run("add", "sub/a.lua", "other.lua")
    run("commit", "-qm", "seed")
    vim.fn.writefile({ "a edited" }, cwd .. "/sub/a.lua")
    local repo_wide, scoped_in, scoped_out
    git.has_unstaged(cwd, nil, function(v)
      repo_wide = v
    end)
    git.has_unstaged(cwd, "sub", function(v)
      scoped_in = v
    end)
    git.has_unstaged(cwd, "other.lua", function(v)
      scoped_out = v
    end)
    vim.wait(4000, function()
      return repo_wide ~= nil and scoped_in ~= nil and scoped_out ~= nil
    end, 10)
    assert.is_true(repo_wide)
    assert.is_true(scoped_in)
    assert.is_false(scoped_out)
  end)

  it("ls_tree lists one level of a directory at a ref", function()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd .. "/src/nested", "p")
    vim.fn.writefile({ "a" }, cwd .. "/src/a.lua")
    vim.fn.writefile({ "b" }, cwd .. "/src/nested/b.lua")
    vim.fn.writefile({ "c" }, cwd .. "/top.lua")
    local function run(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
    end
    run("init", "-q")
    run("config", "user.email", "t@t")
    run("config", "user.name", "t")
    run("add", ".")
    run("commit", "-qm", "init")

    local entries, err
    git.ls_tree(cwd, "HEAD", "src", function(e, er)
      entries, err = e, er
    end)
    vim.wait(4000, function()
      return entries ~= nil or err ~= nil
    end, 10)
    assert.is_nil(err)
    table.sort(entries, function(a, b)
      return a.name < b.name
    end)
    assert.same({
      { name = "a.lua", type = "file", path = "src/a.lua" },
      { name = "nested", type = "dir", path = "src/nested" },
    }, entries)

    local root_entries
    git.ls_tree(cwd, "HEAD", "", function(e)
      root_entries = e
    end)
    vim.wait(4000, function()
      return root_entries ~= nil
    end, 10)
    table.sort(root_entries, function(a, b)
      return a.name < b.name
    end)
    assert.same({
      { name = "src", type = "dir", path = "src" },
      { name = "top.lua", type = "file", path = "top.lua" },
    }, root_entries)
  end)

  it("log_range and stat_range read commit history and diffstat", function()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function run(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
    end
    run("init", "-q")
    run("config", "user.email", "t@t")
    run("config", "user.name", "t")
    vim.fn.writefile({ "1" }, cwd .. "/f.lua")
    run("add", ".")
    run("commit", "-qm", "base")
    local base = vim.trim(vim.system({ "git", "rev-parse", "HEAD" }, { cwd = cwd, text = true }):wait().stdout)
    vim.fn.writefile({ "1", "2" }, cwd .. "/f.lua")
    run("add", ".")
    run("commit", "-qm", "single commit\n\nbody text here")
    local head = vim.trim(vim.system({ "git", "rev-parse", "HEAD" }, { cwd = cwd, text = true }):wait().stdout)

    local commits
    git.log_range(cwd, base, head, function(c)
      commits = c
    end)
    vim.wait(4000, function()
      return commits ~= nil
    end, 10)
    assert.equals(1, #commits)
    assert.equals("single commit", commits[1].subject)
    assert.equals("body text here", commits[1].body)

    local stat
    git.stat_range(cwd, base, head, 60, function(s)
      stat = s
    end)
    vim.wait(4000, function()
      return stat ~= nil
    end, 10)
    assert.is_truthy(stat:match("f%.lua"))
  end)

  it("rev_parse resolves a branch and peels tags, rejects non-commits", function()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function run(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
    end
    run("init", "-q")
    run("branch", "-M", "main")
    run("config", "user.email", "t@t")
    run("config", "user.name", "t")
    vim.fn.writefile({ "1" }, cwd .. "/f.lua")
    run("add", ".")
    run("commit", "-qm", "init")
    local head = vim.trim(vim.system({ "git", "rev-parse", "HEAD" }, { cwd = cwd, text = true }):wait().stdout)
    run("tag", "-a", "-m", "v1", "v1")

    local function resolve(ref)
      local sha, err
      git.rev_parse(cwd, ref, function(s, e)
        sha, err = s, e
      end)
      vim.wait(4000, function()
        return sha ~= nil or err ~= nil
      end, 10)
      return sha, err
    end

    assert.equals(head, (resolve("main")))
    assert.equals(head, (resolve("v1"))) -- annotated tag peeled to its commit
    local sha, err = resolve("nosuchref")
    assert.is_nil(sha)
    assert.is_string(err)

    -- A tree object is not a commit: rejected even though the object exists.
    local tree_sha = vim.trim(vim.system({ "git", "rev-parse", "HEAD^{tree}" }, { cwd = cwd, text = true }):wait().stdout)
    local tree_result, tree_err = resolve(tree_sha)
    assert.is_nil(tree_result)
    assert.is_string(tree_err)
  end)

  it("empty_tree returns a stable hash usable as a diff base", function()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    vim.system({ "git", "init", "-q" }, { cwd = cwd, text = true }):wait()
    local sha
    git.empty_tree(cwd, function(s)
      sha = s
    end)
    vim.wait(4000, function()
      return sha ~= nil
    end, 10)
    assert.is_string(sha)
    assert.equals(40, #sha) -- SHA-1 in this repo's default hash algo
  end)

  it("show reads the INDEX blob", function()
    local mutated = vim.deepcopy(lines)
    mutated[1] = "line 1 staged"
    local cwd, run = make_repo(lines, mutated)
    run("add", "f.lua")
    vim.fn.writefile({ "worktree only" }, cwd .. "/f.lua")
    local content
    git.show(cwd, "INDEX", "f.lua", function(c)
      content = c
    end)
    vim.wait(4000, function()
      return content ~= nil
    end, 10)
    assert.is_truthy(content and content:match("line 1 staged"))
    assert.is_falsy(content and content:match("worktree only"))
  end)
end)
