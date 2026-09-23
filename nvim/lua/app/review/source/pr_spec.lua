local assert = require("luassert")
local pr = require("app.review.source.pr")

describe("pr source (temp repo, gh mocked)", function()
  -- A local checkout plus a bare "remote" it fetches from: real git, but no
  -- network, so fetch failures and successes are both exercised honestly.
  local function make_repo()
    local remote = vim.fn.tempname()
    vim.fn.mkdir(remote, "p")
    local function remote_run(...)
      local r = vim.system({ "git", ... }, { cwd = remote, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
      return vim.trim(r.stdout or "")
    end
    remote_run("init", "-q", "--bare")

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
    run("remote", "add", "origin", remote)
    vim.fn.writefile({ "base" }, cwd .. "/base.lua")
    run("add", ".")
    run("commit", "-qm", "init")
    local main_sha = run("rev-parse", "HEAD")
    run("push", "origin", "main")

    run("checkout", "-qb", "feature")
    vim.fn.writefile({ "a" }, cwd .. "/a.lua")
    run("add", ".")
    run("commit", "-qm", "add a")
    local feature_sha = run("rev-parse", "HEAD")
    run("push", "origin", "feature")

    -- Local main moves ahead too, so merge-base is provably not just "main".
    run("checkout", "-q", "main")
    vim.fn.writefile({ "base2" }, cwd .. "/base.lua")
    run("add", ".")
    run("commit", "-qm", "advance main")
    run("push", "origin", "main")

    return cwd, main_sha, feature_sha
  end

  local function load(source, method)
    method = method or "load"
    local changesets, err
    source[method](source, function(cs, e)
      changesets, err = cs, e
    end)
    vim.wait(10000, function()
      return changesets ~= nil or err ~= nil
    end, 50)
    return changesets, err
  end

  local function gh_view(json_or_result)
    return function(_args, callback)
      if type(json_or_result) == "table" and json_or_result.code then
        callback(json_or_result)
      else
        callback({ code = 0, stdout = vim.json.encode(json_or_result), stderr = "" })
      end
    end
  end

  it("resolves metadata, fetches head and base, and diffs merge-base..head", function()
    local cwd, main_sha, feature_sha = make_repo()
    local calls = {}
    local run = function(args, callback)
      table.insert(calls, args)
      gh_view({ number = 42, title = "Add a.lua", headRefName = "feature", baseRefName = "main" })(args, callback)
    end
    local src = pr.new({ cwd = cwd, classified = { kind = "pr", number = 42 }, run = run })

    assert.is_false(src:can_stage())
    assert.equals("flat", src.default_outline_mode)

    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.equals(feature_sha, changesets[1].head_ref)
    assert.equals(main_sha, changesets[1].base_ref)
    assert.equals("Add a.lua", changesets[1].title)
    assert.is_true(changesets[1].current)

    assert.equals(1, #calls)
    assert.equals("gh", calls[1][1])
    assert.equals("view", calls[1][3])
  end)

  it("passes -R for a URL-derived reference so a foreign PR is repo-scoped", function()
    local cwd = make_repo()
    local calls = {}
    local run = function(args, callback)
      table.insert(calls, args)
      callback({ code = 1, stdout = "", stderr = "gone" })
    end
    local src = pr.new({ cwd = cwd, classified = { kind = "pr", number = 7, repo = "owner/repo" }, run = run })
    load(src)

    local args = calls[1]
    local found = false
    for i, a in ipairs(args) do
      if a == "-R" then
        assert.equals("owner/repo", args[i + 1])
        found = true
      end
    end
    assert.is_true(found)
  end)

  it("names gh as missing when the run seam reports a spawn failure", function()
    local cwd = make_repo()
    local run = function(_args, callback)
      callback({ code = 127, stdout = "", stderr = "ENOENT" })
    end
    local src = pr.new({ cwd = cwd, classified = { kind = "pr", number = 5 }, run = run })
    local changesets, err = load(src)
    assert.is_nil(changesets)
    assert.matches("gh is not installed", err)
  end)

  it("names gh as logged out when gh pr view reports no auth", function()
    local cwd = make_repo()
    local run = function(_args, callback)
      callback({ code = 1, stdout = "", stderr = "You are not logged into any GitHub hosts. Run gh auth login" })
    end
    local src = pr.new({ cwd = cwd, classified = { kind = "pr", number = 5 }, run = run })
    local changesets, err = load(src)
    assert.is_nil(changesets)
    assert.matches("gh is not logged in", err)
  end)

  it("reports a metadata failure for any other gh pr view error", function()
    local cwd = make_repo()
    local run = function(_args, callback)
      callback({ code = 1, stdout = "", stderr = "PR #5 not found" })
    end
    local src = pr.new({ cwd = cwd, classified = { kind = "pr", number = 5 }, run = run })
    local changesets, err = load(src)
    assert.is_nil(changesets)
    assert.matches("PR #5 not found", err)
  end)

  it("names a missing remote rather than guessing a fetch target", function()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function run_git(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
    end
    run_git("init", "-q")
    run_git("config", "user.email", "t@t")
    run_git("config", "user.name", "t")
    vim.fn.writefile({ "base" }, cwd .. "/base.lua")
    run_git("add", ".")
    run_git("commit", "-qm", "init")

    local run = gh_view({ number = 9, title = "x", headRefName = "feature", baseRefName = "main" })
    local src = pr.new({ cwd = cwd, classified = { kind = "pr", number = 9 }, run = run })
    local changesets, err = load(src)
    assert.is_nil(changesets)
    assert.matches("no remote configured", err)
  end)

  it("reports a fetch failure when the reported branch doesn't exist on the remote", function()
    local cwd = make_repo()
    local run = gh_view({ number = 42, title = "x", headRefName = "does-not-exist", baseRefName = "main" })
    local src = pr.new({ cwd = cwd, classified = { kind = "pr", number = 42 }, run = run })
    local changesets, err = load(src)
    assert.is_nil(changesets)
    assert.matches("failed to fetch does%-not%-exist", err)
  end)

  it("refresh is a no-op: no second gh call, same changesets returned", function()
    local cwd = make_repo()
    local calls = 0
    local run = function(args, callback)
      calls = calls + 1
      gh_view({ number = 42, title = "Add a.lua", headRefName = "feature", baseRefName = "main" })(args, callback)
    end
    local src = pr.new({ cwd = cwd, classified = { kind = "pr", number = 42 }, run = run })
    local loaded = load(src)
    assert.equals(1, calls)

    local refreshed, err = load(src, "refresh")
    assert.is_nil(err)
    assert.equals(1, calls)
    assert.same(loaded, refreshed)
  end)
end)
