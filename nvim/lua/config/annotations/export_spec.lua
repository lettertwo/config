local assert = require("luassert")
local Export = require("config.annotations.export")

local function write_file(dir, name, lines)
  vim.fn.writefile(lines, vim.fs.joinpath(dir, name))
end

describe("Config.Annotations.Export", function()
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
  end)

  after_each(function()
    vim.fn.delete(dir, "rf")
  end)

  it("renders a single-line annotation with 3 lines of context on each side", function()
    local lines = {}
    for i = 1, 10 do
      lines[i] = "line " .. i
    end
    write_file(dir, "f.lua", lines)

    local rec = {
      id = "1",
      file = "f.lua",
      lnum = 5,
      end_lnum = 5,
      anchor_text = "line 5",
      body = "rename this",
      created_at = 0,
    }

    local out = Export.render({ rec }, dir, "batch-1")

    assert.matches("## f%.lua:5  %(id: 1%)", out)
    assert.matches("```lua", out)
    assert.matches("  line 2\n  line 3\n  line 4\n> line 5\n  line 6\n  line 7\n  line 8", out)
    assert.matches("rename this", out)
    assert.matches("Batch: batch%-1", out)
  end)

  it("renders a multi-line annotation with a range heading and marked span", function()
    local lines = {}
    for i = 1, 10 do
      lines[i] = "line " .. i
    end
    write_file(dir, "g.lua", lines)

    local rec = {
      id = "2",
      file = "g.lua",
      lnum = 4,
      end_lnum = 6,
      anchor_text = "line 4\nline 5\nline 6",
      body = "extract this block",
      created_at = 0,
    }

    local out = Export.render({ rec }, dir, "batch-2")

    assert.matches("## g%.lua:4%-6  %(id: 2%)", out)
    assert.matches("  line 1\n  line 2\n  line 3\n> line 4\n> line 5\n> line 6\n  line 7\n  line 8\n  line 9", out)
    assert.matches("extract this block", out)
  end)

  it("heads a rev-keyed section with the short sha or index and reads context from that rev", function()
    local function git(...)
      local r = vim.system({ "git", ... }, { cwd = dir, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
      return vim.trim(r.stdout)
    end
    git("config", "user.email", "t@t")
    git("config", "user.name", "t")
    write_file(dir, "h.lua", { "old 1", "old 2", "old 3" })
    git("add", ".")
    git("commit", "-qm", "one")
    local sha = git("rev-parse", "HEAD")
    write_file(dir, "h.lua", { "new 1", "new 2", "new 3" })
    git("add", ".")
    write_file(dir, "h.lua", { "tree 1", "tree 2", "tree 3" })

    local base = { file = "h.lua", lnum = 2, end_lnum = 2, anchor_text = "x", body = "b", created_at = 0 }
    local at_sha = vim.tbl_extend("force", base, { id = "3", rev = sha })
    local at_index = vim.tbl_extend("force", base, { id = "4", rev = "index" })
    local out = Export.render({ at_sha, at_index }, dir, "batch-3")

    assert.matches("## h%.lua:2 @ " .. sha:sub(1, 7) .. "  %(id: 3%)", out)
    assert.matches("## h%.lua:2 @ index  %(id: 4%)", out)
    assert.matches("> old 2", out)
    assert.matches("> new 2", out)
    assert.is_nil(out:find("tree 2", 1, true))
  end)

  it("write() renders the records into a feedback file under the git dir and returns its path", function()
    write_file(dir, "f.lua", { "one", "two", "three" })
    local rec = { id = "1", file = "f.lua", lnum = 2, end_lnum = 2, anchor_text = "two", body = "fix", created_at = 0 }

    local path, batch = Export.write({ rec }, dir)

    assert.is_not_nil(path)
    assert.equals(1, vim.fn.filereadable(path))
    assert.matches("claude%-annotations/feedback%-" .. batch .. "%.md$", path)
    assert.matches("## f%.lua:2  %(id: 1%)", table.concat(vim.fn.readfile(path), "\n"))
  end)

  it("write() reports an error outside a git worktree", function()
    local outside = vim.fn.tempname()
    vim.fn.mkdir(outside, "p")
    local path, err = Export.write({}, outside)
    vim.fn.delete(outside, "rf")
    assert.is_nil(path)
    assert.is_string(err)
  end)
end)
