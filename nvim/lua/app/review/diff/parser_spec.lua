local assert = require("luassert")
local parser = require("app.review.diff.parser")

-- Join diff lines with real newlines (specs read better as line lists).
local function diff(lines)
  return table.concat(lines, "\n") .. "\n"
end

describe("parser.parse", function()
  it("parses a simple modification with line numbers", function()
    local files = parser.parse(diff({
      "diff --git a/foo.lua b/foo.lua",
      "index 1234567..89abcde 100644",
      "--- a/foo.lua",
      "+++ b/foo.lua",
      "@@ -1,3 +1,3 @@",
      " local a = 1",
      "-local b = 2",
      "+local b = 20",
      " return a + b",
    }))
    assert.equals(1, #files)
    local f = files[1]
    assert.equals("foo.lua", f.path)
    assert.equals("M", f.status)
    assert.is_nil(f.old_path)
    assert.equals(1, #f.hunks)
    local h = f.hunks[1]
    assert.same({ old_start = 1, old_count = 3, new_start = 1, new_count = 3 }, {
      old_start = h.old_start,
      old_count = h.old_count,
      new_start = h.new_start,
      new_count = h.new_count,
    })
    assert.same({ "ctx", "del", "add", "ctx" }, vim.tbl_map(function(l)
      return l.kind
    end, h.lines))
    -- del carries old_lnum only; add carries new_lnum only; ctx carries both
    assert.equals(2, h.lines[2].old_lnum)
    assert.is_nil(h.lines[2].new_lnum)
    assert.equals(2, h.lines[3].new_lnum)
    assert.is_nil(h.lines[3].old_lnum)
    assert.equals(3, h.lines[4].old_lnum)
    assert.equals(3, h.lines[4].new_lnum)
  end)

  it("parses added and deleted files", function()
    local files = parser.parse(diff({
      "diff --git a/new.lua b/new.lua",
      "new file mode 100644",
      "index 0000000..1111111",
      "--- /dev/null",
      "+++ b/new.lua",
      "@@ -0,0 +1,2 @@",
      "+line one",
      "+line two",
      "diff --git a/old.lua b/old.lua",
      "deleted file mode 100644",
      "index 2222222..0000000",
      "--- a/old.lua",
      "+++ /dev/null",
      "@@ -1,2 +0,0 @@",
      "-line one",
      "-line two",
    }))
    assert.equals(2, #files)
    assert.equals("A", files[1].status)
    assert.equals("D", files[2].status)
    assert.equals(2, files[2].hunks[1].old_count)
    assert.equals(0, files[2].hunks[1].new_count)
  end)

  it("parses renames", function()
    local files = parser.parse(diff({
      "diff --git a/before.lua b/after.lua",
      "similarity index 90%",
      "rename from before.lua",
      "rename to after.lua",
    }))
    assert.equals("R", files[1].status)
    assert.equals("after.lua", files[1].path)
    assert.equals("before.lua", files[1].old_path)
  end)

  it("parses binary files", function()
    local files = parser.parse(diff({
      "diff --git a/img.png b/img.png",
      "index 1234567..89abcde 100644",
      "Binary files a/img.png and b/img.png differ",
    }))
    assert.equals("B", files[1].status)
    assert.equals(0, #files[1].hunks)
  end)

  it("does not swallow deleted lines that look like file headers", function()
    local files = parser.parse(diff({
      "diff --git a/doc.md b/doc.md",
      "--- a/doc.md",
      "+++ b/doc.md",
      "@@ -1,2 +1,1 @@",
      "--- this deleted line starts with dashes",
      " context",
    }))
    local h = files[1].hunks[1]
    assert.equals("del", h.lines[1].kind)
    assert.equals("-- this deleted line starts with dashes", h.lines[1].text)
  end)

  it("captures raw hunk bytes including no-newline markers", function()
    local files = parser.parse(diff({
      "diff --git a/f b/f",
      "--- a/f",
      "+++ b/f",
      "@@ -1 +1 @@",
      "-old",
      "\\ No newline at end of file",
      "+new",
      "\\ No newline at end of file",
    }))
    assert.same({
      "@@ -1 +1 @@",
      "-old",
      "\\ No newline at end of file",
      "+new",
      "\\ No newline at end of file",
    }, files[1].hunks[1].raw)
    -- markers are raw-only, not HunkLines
    assert.equals(2, #files[1].hunks[1].lines)
  end)

  it("handles singular hunk headers (count omitted = 1)", function()
    local files = parser.parse(diff({
      "diff --git a/f b/f",
      "--- a/f",
      "+++ b/f",
      "@@ -3 +3 @@",
      "-x",
      "+y",
    }))
    local h = files[1].hunks[1]
    assert.equals(1, h.old_count)
    assert.equals(1, h.new_count)
  end)
end)

describe("parser.hunk_to_patch", function()
  local function apply_check(cwd, patch, opts)
    local args = { "git", "apply", "--check" }
    vim.list_extend(args, opts or {})
    table.insert(args, "-")
    local r = vim.system(args, { cwd = cwd, stdin = patch, text = true }):wait()
    return r.code == 0, r.stderr
  end

  -- Round-trip fixture: real repo, real diff, reconstructed patches must be
  -- accepted by `git apply --check --cached`. This is the M5 staging
  -- acceptance path — the POC had a "corrupt patch" bug on pure-del hunks.
  local function make_repo(setup, mutate)
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function git(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
    end
    git("init", "-q")
    git("config", "user.email", "t@t")
    git("config", "user.name", "t")
    vim.fn.writefile(setup, cwd .. "/f.lua")
    git("add", ".")
    git("commit", "-qm", "init")
    vim.fn.writefile(mutate, cwd .. "/f.lua")
    local r = vim.system(
      { "git", "diff", "--no-color", "--unified=3", "HEAD" },
      { cwd = cwd, text = true }
    ):wait()
    return cwd, parser.parse(r.stdout)
  end

  it("reconstructs an applicable patch for a mixed hunk", function()
    local cwd, files = make_repo(
      { "a", "b", "c", "d", "e" },
      { "a", "B", "c", "d", "e", "f" }
    )
    local patch = parser.hunk_to_patch(files[1], files[1].hunks[1])
    local ok, err = apply_check(cwd, patch, { "--cached" })
    assert.is_true(ok, err)
  end)

  it("reconstructs an applicable patch for a pure-deletion hunk", function()
    local lines = {}
    for i = 1, 20 do
      lines[i] = "line " .. i
    end
    local mutated = vim.deepcopy(lines)
    table.remove(mutated, 10)
    table.remove(mutated, 10) -- delete lines 10-11, no additions
    local cwd, files = make_repo(lines, mutated)
    local h = files[1].hunks[1]
    assert.equals(0, #vim.tbl_filter(function(l)
      return l.kind == "add"
    end, h.lines))
    local patch = parser.hunk_to_patch(files[1], h)
    local ok, err = apply_check(cwd, patch, { "--cached" })
    assert.is_true(ok, err)
  end)
end)

describe("parser.hunk_to_patch_lines", function()
  local file = { path = "f.lua", hunks = {} }
  local hunk = parser.parse(diff({
    "diff --git a/f.lua b/f.lua",
    "--- a/f.lua",
    "+++ b/f.lua",
    "@@ -1,4 +1,4 @@",
    " ctx1",
    "-del1",
    "-del2",
    "+add1",
    "+add2",
    " ctx2",
  }))[1].hunks[1]

  it("keeps everything when all predicates return true", function()
    local patch = parser.hunk_to_patch_lines(file, hunk, function()
      return true
    end, function()
      return true
    end)
    assert.truthy(patch:find("@@ -1,4 +1,4 @@", 1, true))
    assert.truthy(patch:find("-del1", 1, true))
    assert.truthy(patch:find("+add2", 1, true))
    assert.equals("\n", patch:sub(-1))
  end)

  it("omits dropped adds and converts dropped dels to context", function()
    local patch = parser.hunk_to_patch_lines(file, hunk, function(e)
      return e.text == "add1"
    end, function(e)
      return e.text == "del1"
    end)
    -- old side: ctx1 + del1 + del2-as-ctx + ctx2 = 4
    -- new side: ctx1 + del2-as-ctx + add1 + ctx2 = 4
    assert.truthy(patch:find("@@ -1,4 +1,4 @@", 1, true))
    assert.truthy(patch:find("\n del2", 1, true))
    assert.is_nil(patch:find("+add2", 1, true))
  end)
end)
