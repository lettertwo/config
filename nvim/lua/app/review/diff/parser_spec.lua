local assert = require("luassert")
local parser = require("app.review.diff.parser")

-- Join diff lines with real newlines (specs read better as line lists).
local function diff(lines)
  return table.concat(lines, "\n") .. "\n"
end

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

  it("base=new mirrors the drop rules: adds to context, dels omitted", function()
    local patch = parser.hunk_to_patch_lines(file, hunk, function(e)
      return e.text == "add1"
    end, function(e)
      return e.text == "del1"
    end, "new")
    -- old side: ctx1 + del1 + add2-as-ctx + ctx2 = 4
    -- new side: ctx1 + add1 + add2-as-ctx + ctx2 = 4
    assert.truthy(patch:find("@@ -1,4 +1,4 @@", 1, true))
    assert.truthy(patch:find("\n add2", 1, true))
    assert.truthy(patch:find("+add1", 1, true))
    assert.truthy(patch:find("-del1", 1, true))
    assert.is_nil(patch:find("del2", 1, true))
  end)

  -- Round-trips against real git: partial selections must apply in both
  -- directions. The reverse direction is where the base parameter earns its
  -- keep — "old"-rule patches reference dropped lines on a side they don't
  -- exist on, and git rejects them.
  describe("round-trip", function()
    -- setup {a,b,c,d,e} → mutate {a,B,c,d,e,f}: one hunk, a b→B change plus
    -- a trailing +f add. Selection = just the "f" line.
    local function partial_patch(files, base)
      return parser.hunk_to_patch_lines(files[1], files[1].hunks[1], function(e)
        return e.text == "f"
      end, function()
        return false
      end, base)
    end

    it("stages a partial selection onto the index (base=old, forward)", function()
      local cwd, files = make_repo({ "a", "b", "c", "d", "e" }, { "a", "B", "c", "d", "e", "f" })
      local ok, err = apply_check(cwd, partial_patch(files, "old"), { "--cached" })
      assert.is_true(ok, err)
    end)

    it("unstages a partial selection from the index (base=new, reverse)", function()
      local cwd, files = make_repo({ "a", "b", "c", "d", "e" }, { "a", "B", "c", "d", "e", "f" })
      -- Stage everything, then re-diff HEAD→INDEX: the staged-pane coordinates.
      local r = vim.system({ "git", "add", "." }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
      r = vim.system({ "git", "diff", "--no-color", "--cached", "HEAD" }, { cwd = cwd, text = true }):wait()
      files = parser.parse(r.stdout)

      local ok, err = apply_check(cwd, partial_patch(files, "new"), { "--cached", "--reverse" })
      assert.is_true(ok, err)
      -- Tripwire: the forward drop rules must NOT reverse-apply.
      assert.is_false(apply_check(cwd, partial_patch(files, "old"), { "--cached", "--reverse" }))
    end)

    it("unstages a kept DELETION with dropped adds as context (base=new, reverse)", function()
      -- The staged-pane LEFT-side gesture: keep only the del of the b→B
      -- change; the adds (B, f) stay in the index and must appear as context.
      local cwd, files = make_repo({ "a", "b", "c", "d", "e" }, { "a", "B", "c", "d", "e", "f" })
      local r = vim.system({ "git", "add", "." }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
      r = vim.system({ "git", "diff", "--no-color", "--cached", "HEAD" }, { cwd = cwd, text = true }):wait()
      files = parser.parse(r.stdout)

      local patch = parser.hunk_to_patch_lines(files[1], files[1].hunks[1], function()
        return false
      end, function(e)
        return e.text == "b"
      end, "new")
      local ok, err = apply_check(cwd, patch, { "--cached", "--reverse" })
      assert.is_true(ok, err)
    end)

    it("splices a no-newline EOF context so a kept add doesn't concatenate", function()
      -- Both sides end without a trailing newline. Keep only the SECOND add:
      -- the dels convert to context, and the old-EOF "\ No newline" marker
      -- lands mid-body. Without the del+re-add splice git ACCEPTS the patch
      -- and silently concatenates the kept add onto the no-newline line
      -- (blob "…old_lastnew_two").
      local cwd = vim.fn.tempname()
      vim.fn.mkdir(cwd, "p")
      local function git(...)
        local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
        assert.equals(0, r.code, r.stderr)
        return r
      end
      git("init", "-q")
      git("config", "user.email", "t@t")
      git("config", "user.name", "t")
      vim.fn.writefile({ "a", "b", "old_last" }, cwd .. "/f.lua", "b") -- no trailing newline
      git("add", ".")
      git("commit", "-qm", "init")
      vim.fn.writefile({ "a", "b", "new_one", "new_two" }, cwd .. "/f.lua", "b")
      local r = vim.system({ "git", "diff", "--no-color", "--unified=3", "HEAD" }, { cwd = cwd, text = true }):wait()
      local files = parser.parse(r.stdout)

      local patch = parser.hunk_to_patch_lines(files[1], files[1].hunks[1], function(e)
        return e.text == "new_two"
      end, function()
        return false
      end, "old")
      local ar = vim.system({ "git", "apply", "--cached", "-" }, { cwd = cwd, text = true, stdin = patch }):wait()
      assert.equals(0, ar.code, ar.stderr)
      local blob = vim.system({ "git", "show", ":f.lua" }, { cwd = cwd, text = true }):wait()
      assert.equals("a\nb\nold_last\nnew_two", blob.stdout)
    end)

    it("stages part of a pure-deletion run (base=old, forward)", function()
      local lines = {}
      for i = 1, 20 do
        lines[i] = "line " .. i
      end
      local mutated = vim.deepcopy(lines)
      table.remove(mutated, 10)
      table.remove(mutated, 10) -- delete lines 10-11, no additions
      local cwd, files = make_repo(lines, mutated)
      local patch = parser.hunk_to_patch_lines(files[1], files[1].hunks[1], function()
        return false
      end, function(e)
        return e.text == "line 10"
      end)
      local ok, err = apply_check(cwd, patch, { "--cached" })
      assert.is_true(ok, err)
    end)
  end)
end)

describe("parser.line_predicates", function()
  local function hunk_of(body)
    local header = { "diff --git a/f.lua b/f.lua", "--- a/f.lua", "+++ b/f.lua" }
    return parser.parse(diff(vim.list_extend(header, body)))[1].hunks[1]
  end

  -- new side: ctx1=1, add1=2, add2=3, ctx2=4; dels anchored at add1 (lnum 2).
  local change = hunk_of({
    "@@ -1,4 +1,4 @@",
    " ctx1",
    "-del1",
    "-del2",
    "+add1",
    "+add2",
    " ctx2",
  })

  local function texts(hunk, ka, kd)
    local kept = {}
    for _, e in ipairs(hunk.lines) do
      if (e.kind == "add" and ka(e)) or (e.kind == "del" and kd(e)) then
        table.insert(kept, e.text)
      end
    end
    return kept
  end

  it("RIGHT: selecting the first add takes the paired del run with it", function()
    local ka, kd, kept = parser.line_predicates(change, "RIGHT", 2, 2)
    assert.equals(3, kept)
    assert.same({ "del1", "del2", "add1" }, texts(change, ka, kd))
  end)

  it("RIGHT: selecting a later add leaves the del run behind", function()
    local ka, kd, kept = parser.line_predicates(change, "RIGHT", 3, 3)
    assert.equals(1, kept)
    assert.same({ "add2" }, texts(change, ka, kd))
  end)

  it("RIGHT: a context-only selection keeps nothing", function()
    local _, _, kept = parser.line_predicates(change, "RIGHT", 1, 1)
    assert.equals(0, kept)
  end)

  it("RIGHT: a mid-hunk pure-del run sits on the line above its virt block", function()
    -- new side: keep1=1, keep2=2; dels render above keep2, nav target keep1.
    local h = hunk_of({
      "@@ -1,4 +1,2 @@",
      " keep1",
      "-gone1",
      "-gone2",
      " keep2",
    })
    local ka, kd, kept = parser.line_predicates(h, "RIGHT", 1, 1)
    assert.equals(2, kept)
    assert.same({ "gone1", "gone2" }, texts(h, ka, kd))
    local _, _, none = parser.line_predicates(h, "RIGHT", 2, 2)
    assert.equals(0, none)
  end)

  it("RIGHT: a hunk-leading del run clamps into the hunk", function()
    local h = hunk_of({
      "@@ -1,3 +1,1 @@",
      "-gone1",
      "-gone2",
      " keep",
    })
    local _, kd, kept = parser.line_predicates(h, "RIGHT", 1, 1)
    assert.equals(2, kept)
    assert.is_true(kd(h.lines[1]))
  end)

  it("RIGHT: a dels-only hunk anchors at new_start", function()
    local h = hunk_of({
      "@@ -9,2 +8,0 @@",
      "-gone1",
      "-gone2",
    })
    local _, _, kept = parser.line_predicates(h, "RIGHT", 8, 8)
    assert.equals(2, kept)
    local _, _, none = parser.line_predicates(h, "RIGHT", 7, 7)
    assert.equals(0, none)
  end)

  it("LEFT: dels match old lnums exactly and adds never match", function()
    -- old side: ctx1=1, del1=2, del2=3, ctx2=4
    local ka, kd, kept = parser.line_predicates(change, "LEFT", 2, 2)
    assert.equals(1, kept)
    assert.same({ "del1" }, texts(change, ka, kd))
    local ka2, kd2, kept2 = parser.line_predicates(change, "LEFT", 1, 4)
    assert.equals(2, kept2)
    assert.same({ "del1", "del2" }, texts(change, ka2, kd2))
    assert.is_false(ka2(change.lines[4])) -- add1 stays unselected from the left
  end)
end)
