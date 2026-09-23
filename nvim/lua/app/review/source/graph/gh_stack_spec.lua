local assert = require("luassert")
local gh_stack = require("app.review.source.graph.gh_stack")

local function tmp_common_dir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

local function write_file(path, data)
  vim.fn.writefile({ vim.json.encode(data) }, path)
end

local function stack_doc(stacks)
  return { schemaVersion = 1, repository = "host:owner/repo", stacks = stacks }
end

describe("gh_stack.new", function()
  it("reads the canonical file and folds branches into a parent chain", function()
    local common = tmp_common_dir()
    write_file(common .. "/gh-stack", stack_doc({
      {
        trunk = { branch = "main", head = "9566b29" },
        branches = {
          { branch = "a", head = "aaa", base = "trunk-rev" },
          { branch = "b", head = "bbb", base = "aaa" },
        },
      },
    }))

    local g = gh_stack.new("unused-cwd", common, "b")
    local nodes = g:nodes()
    assert.same({ "a", "b" }, vim.tbl_map(function(n)
      return n.id
    end, nodes))
    assert.equals("trunk-rev", g:base_ref(nodes[1]))
    -- head_ref always resolves the live branch, never the file's recorded
    -- (and immediately stale) head.
    assert.equals("refs/heads/b", g:head_ref(nodes[2]))
  end)

  it("returns no nodes for a branch the file doesn't track", function()
    local common = tmp_common_dir()
    write_file(common .. "/gh-stack", stack_doc({
      { trunk = { branch = "main" }, branches = { { branch = "a" } } },
    }))
    local g = gh_stack.new("unused-cwd", common, "untracked")
    assert.same({}, g:nodes())
  end)

  it("carries pr_number only, no title", function()
    local common = tmp_common_dir()
    write_file(common .. "/gh-stack", stack_doc({
      {
        trunk = { branch = "main" },
        branches = { { branch = "a", pullRequest = { number = 42, url = "https://x" } } },
      },
    }))
    local g = gh_stack.new("unused-cwd", common, "a")
    local meta = g:metadata(g:nodes()[1])
    assert.equals(42, meta.pr_number)
    assert.is_nil(meta.title)
  end)

  it("unions the canonical file with unlinked worktree files", function()
    local common = tmp_common_dir()
    write_file(common .. "/gh-stack", stack_doc({
      { trunk = { branch = "main" }, branches = { { branch = "a" } } },
    }))
    vim.fn.mkdir(common .. "/worktrees/wt1", "p")
    write_file(common .. "/worktrees/wt1/gh-stack", stack_doc({
      { trunk = { branch = "main" }, branches = { { branch = "c" } } },
    }))

    local g = gh_stack.new("unused-cwd", common, "c")
    assert.equals(1, #g:nodes())
    assert.equals("c", g:nodes()[1].branch)
  end)

  it("first wins wholesale when canonical and a worktree file share identity", function()
    local common = tmp_common_dir()
    write_file(common .. "/gh-stack", stack_doc({
      { number = 7, trunk = { branch = "main" }, branches = { { branch = "a" } } },
    }))
    vim.fn.mkdir(common .. "/worktrees/wt1", "p")
    -- Same stack number, different (stale) branch list — must be dropped
    -- wholesale rather than merged in.
    write_file(common .. "/worktrees/wt1/gh-stack", stack_doc({
      { number = 7, trunk = { branch = "main" }, branches = { { branch = "a" }, { branch = "b" } } },
    }))

    local g = gh_stack.new("unused-cwd", common, "b")
    assert.same({}, g:nodes()) -- "b" only exists in the discarded duplicate
  end)

  it("excludes a worktree gh-stack that is a symlink, even a dangling one", function()
    local common = tmp_common_dir()
    write_file(common .. "/gh-stack", stack_doc({
      { trunk = { branch = "main" }, branches = { { branch = "a" } } },
    }))
    vim.fn.mkdir(common .. "/worktrees/wt1", "p")
    -- Points at a canonical file that doesn't exist yet — a valid state that
    -- must not be resolved, only checked lexically.
    assert.is_true(vim.uv.fs_symlink("../../gh-stack-not-yet-created", common .. "/worktrees/wt1/gh-stack") ~= nil)

    local g = gh_stack.new("unused-cwd", common, "a")
    assert.equals(1, #g:nodes()) -- only the canonical entry, symlink ignored
  end)

  it("skips a stack entry with no well-formed trunk, without failing the read", function()
    local common = tmp_common_dir()
    write_file(common .. "/gh-stack", stack_doc({
      { branches = { { branch = "orphan" } } }, -- no trunk at all
      { trunk = { branch = "main" }, branches = { { branch = "a" } } },
    }))
    local g = gh_stack.new("unused-cwd", common, "a")
    assert.equals(1, #g:nodes())
    local none = gh_stack.new("unused-cwd", common, "orphan")
    assert.same({}, none:nodes())
  end)

  it("raises on a schemaVersion this reader doesn't understand", function()
    local common = tmp_common_dir()
    write_file(common .. "/gh-stack", { schemaVersion = 2, stacks = {} })
    local ok = pcall(gh_stack.new, "unused-cwd", common, "a")
    assert.is_false(ok)
  end)
end)
