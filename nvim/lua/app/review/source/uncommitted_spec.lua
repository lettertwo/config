local assert = require("luassert")
local uncommitted = require("app.review.source.uncommitted")
local merge_files = uncommitted._merge_files

local function diff(lines)
  return table.concat(lines, "\n") .. "\n"
end

-- Minimal single-file diff blob with one changed line.
local function blob(path, opts)
  opts = opts or {}
  local out = { "diff --git a/" .. path .. " b/" .. path }
  if opts.new_file then
    table.insert(out, "new file mode 100644")
  end
  vim.list_extend(out, {
    "--- a/" .. path,
    "+++ b/" .. path,
    "@@ -1 +1 @@",
    "-old " .. path,
    "+new " .. path,
  })
  return diff(out)
end

describe("uncommitted._merge_files", function()
  it("takes the union of paths across the three diffs", function()
    local files = merge_files(
      blob("both.lua") .. blob("worktree-only.lua"),
      blob("staged-only.lua"),
      blob("worktree-only.lua"),
      {}
    )
    assert.same(
      { "both.lua", "staged-only.lua", "worktree-only.lua" },
      vim.tbl_map(function(f)
        return f.path
      end, files)
    )
  end)

  it("synthesizes a primary for staged-then-worktree-reverted files", function()
    -- staged diff has the file; combined does not (net no-op vs HEAD)
    local files = merge_files("", blob("reverted.lua"), "", {})
    assert.equals(1, #files)
    local f = files[1]
    assert.equals("reverted.lua", f.path)
    assert.equals(0, #f.hunks) -- no combined hunks
    assert.is_table(f.staged_change)
    assert.equals("HEAD", f.staged_change.base_ref)
    assert.equals("INDEX", f.staged_change.head_ref)
  end)

  it("tags untracked files with status U", function()
    local files = merge_files(blob("fresh.lua", { new_file = true }), "", blob("fresh.lua", { new_file = true }), { "fresh.lua" })
    assert.equals("U", files[1].status)
  end)

  it("attaches staged and unstaged sub-diffs with correct refs", function()
    local files = merge_files(blob("f.lua"), blob("f.lua"), blob("f.lua"), {})
    local f = files[1]
    assert.equals("HEAD", f.staged_change.base_ref)
    assert.equals("INDEX", f.staged_change.head_ref)
    assert.equals("INDEX", f.unstaged.base_ref)
    assert.equals("WORKTREE", f.unstaged.head_ref)
    -- both present → partial-stage summary fields for the outline
    assert.is_nil(f.staged)
    assert.equals(f.staged_change.hunks, f.staged_hunks)
  end)

  it("marks fully-staged files (staged, no unstaged hunks)", function()
    local files = merge_files(blob("f.lua"), blob("f.lua"), "", {})
    local f = files[1]
    assert.is_true(f.staged)
    assert.is_nil(f.staged_hunks)
    assert.is_nil(f.unstaged)
  end)

  it("sorts by path", function()
    local files = merge_files(blob("z.lua") .. blob("a.lua") .. blob("m.lua"), "", "", {})
    assert.same({ "a.lua", "m.lua", "z.lua" }, vim.tbl_map(function(f)
      return f.path
    end, files))
  end)
end)
