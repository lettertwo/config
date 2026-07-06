local assert = require("luassert")
local ref = require("app.review.source.ref")

describe("ref._parse_ref", function()
  it("defaults to HEAD when nil or empty", function()
    assert.same({ kind = "single", ref = "HEAD" }, (ref._parse_ref(nil)))
    assert.same({ kind = "single", ref = "HEAD" }, (ref._parse_ref("")))
  end)

  it("parses a single ref", function()
    assert.same({ kind = "single", ref = "feature" }, (ref._parse_ref("feature")))
  end)

  it("parses a base..head range", function()
    assert.same({ kind = "range", base = "main", head = "feature" }, (ref._parse_ref("main..feature")))
  end)

  it("defaults an empty range side to HEAD", function()
    assert.same({ kind = "range", base = "main", head = "HEAD" }, (ref._parse_ref("main..")))
    assert.same({ kind = "range", base = "HEAD", head = "feature" }, (ref._parse_ref("..feature")))
  end)

  it("rejects three-dot ranges", function()
    local parsed, err = ref._parse_ref("main...feature")
    assert.is_nil(parsed)
    assert.is_string(err)
  end)
end)

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

    -- Dirty worktree file: proves range/single reviews never surface it.
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

  it("single ref: one changeset diffing <ref>^..<ref>", function()
    local cwd, _, _, a_sha, b_sha = make_repo()
    local src = ref.new({ cwd = cwd, ref = "feature" })
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

  it("range: per-commit changesets with adjacent-sha base/head, never WORKTREE", function()
    local cwd, _, main_sha, a_sha, b_sha = make_repo()
    local src = ref.new({ cwd = cwd, ref = "main..feature" })
    assert.equals("stack", src.default_outline_mode)
    assert.equals("base-first", src.default_stack_order)
    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(2, #changesets)
    -- The oldest changeset's base is the range's `base` arg verbatim (a
    -- branch name here, not resolved to a sha) — same convention as the
    -- stack source's git-graph fallback. Only the seam between commits is
    -- guaranteed to be adjacent shas.
    assert.equals("main", changesets[1].base_ref)
    assert.equals(a_sha, changesets[1].head_ref)
    assert.equals(a_sha, changesets[2].base_ref)
    assert.equals(b_sha, changesets[2].head_ref)
    assert.is_true(changesets[1].current)
    for _, cs in ipairs(changesets) do
      for _, f in ipairs(cs.files) do
        assert.are_not.equal("WORKTREE", f.head_ref)
      end
    end
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

    local src = ref.new({ cwd = cwd, ref = "HEAD" })
    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.equals(1, #changesets[1].files)
    assert.equals("A", changesets[1].files[1].status)
  end)

  it("invalid ref surfaces an error", function()
    local cwd = make_repo()
    local src = ref.new({ cwd = cwd, ref = "nosuchref" })
    local changesets, err = load(src)
    assert.is_nil(changesets)
    assert.is_string(err)
  end)

  it("X..X range produces one empty changeset without crashing", function()
    local cwd = make_repo()
    local src = ref.new({ cwd = cwd, ref = "feature..feature" })
    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.same({}, changesets[1].files)
  end)

  it("bare HEAD default with no ref argument", function()
    local cwd, _, _, a_sha, b_sha = make_repo()
    local src = ref.new({ cwd = cwd })
    local changesets, err = load(src)
    assert.is_nil(err)
    assert.equals(1, #changesets)
    assert.equals(b_sha, changesets[1].head_ref)
    assert.equals(a_sha, changesets[1].base_ref)
  end)
end)
