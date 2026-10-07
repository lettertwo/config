local assert = require("luassert")
local reviewed = require("app.review.reviewed")

local function make_repo()
  local cwd = vim.fn.tempname()
  vim.fn.mkdir(cwd, "p")
  local r = vim.system({ "git", "init", "-q" }, { cwd = cwd, text = true }):wait()
  assert.equals(0, r.code, r.stderr)
  return cwd
end

local function fc(path, old, new)
  return { path = path, status = "M", hunks = {}, changeset_id = "x", old_blob = old, new_blob = new }
end

describe("reviewed", function()
  local cwd, seen

  before_each(function()
    cwd = make_repo()
    reviewed.use(cwd)
    seen = 0
    vim.api.nvim_create_autocmd("User", {
      pattern = "ReviewReviewedChanged",
      group = vim.api.nvim_create_augroup("ReviewedSpec", { clear = true }),
      callback = function()
        seen = seen + 1
      end,
    })
  end)

  after_each(function()
    reviewed.use(nil)
    vim.api.nvim_create_augroup("ReviewedSpec", { clear = true })
  end)

  it("round-trips a mark through the JSON file in the common dir", function()
    local f = fc("a.lua", "1", "2")
    assert.is_false(reviewed.is_reviewed(f))
    assert.is_true(reviewed.toggle(f))
    assert.is_true(reviewed.is_reviewed(f))
    assert.equals(1, vim.fn.filereadable(cwd .. "/.git/review/reviewed.json"))
    assert.equals(1, seen)
    -- Same marks after a fresh load from disk.
    reviewed.use(cwd)
    assert.is_true(reviewed.is_reviewed(f))
    assert.is_false(reviewed.toggle(f))
    assert.is_false(reviewed.is_reviewed(f))
    assert.equals(2, seen)
  end)

  it("reads a file whose new blob changed as unreviewed", function()
    reviewed.toggle(fc("a.lua", "1", "2"))
    assert.is_false(reviewed.is_reviewed(fc("a.lua", "1", "3")))
    assert.is_false(reviewed.is_reviewed(fc("a.lua", "0", "2")))
    assert.is_true(reviewed.is_reviewed(fc("a.lua", "1", "2")))
  end)

  it("counts the reviewed files in a list", function()
    local files = { fc("a.lua", "1", "2"), fc("b.lua", "1", "2"), fc("c.lua", "1", "2") }
    assert.equals(0, reviewed.count(files))
    reviewed.toggle(files[1])
    reviewed.toggle(files[3])
    assert.equals(2, reviewed.count(files))
  end)

  it("keeps marks another writer put on disk", function()
    local a, b = fc("a.lua", "1", "2"), fc("b.lua", "1", "2")
    reviewed.toggle(a)
    local path = cwd .. "/.git/review/reviewed.json"
    local set = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    set[table.concat({ "b.lua", "1", "2" }, "\0")] = { at = 1 }
    vim.fn.writefile({ vim.json.encode(set) }, path)
    reviewed.toggle(fc("c.lua", "1", "2"))
    assert.is_true(reviewed.is_reviewed(a))
    assert.is_true(reviewed.is_reviewed(b))
  end)
end)
