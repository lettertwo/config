local assert = require("luassert")
local Store = require("config.annotations.store")

local function tmp_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
  return dir
end

describe("Config.Annotations.Store", function()
  local dir, prev_cwd

  before_each(function()
    prev_cwd = vim.uv.cwd()
    dir = tmp_repo()
    vim.uv.chdir(dir)
    Store._reset_cache()
  end)

  after_each(function()
    vim.uv.chdir(prev_cwd)
    vim.fn.delete(dir, "rf")
  end)

  it("round-trips a record through add/save/load", function()
    Store.add({
      id = "1",
      file = "f.lua",
      lnum = 3,
      end_lnum = 3,
      anchor_text = "local x = 1",
      body = "rename this",
      created_at = 100,
    })

    Store._reset_cache()
    local records = Store.load()
    assert.equals(1, #records)
    assert.equals("f.lua", records[1].file)
    assert.equals(3, records[1].lnum)
    assert.equals("rename this", records[1].body)
    assert.is_nil(records[1].sent_at)
  end)

  it("filters pending records by absence of sent_at", function()
    Store.add({ id = "1", file = "f.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.add({ id = "2", file = "f.lua", lnum = 2, end_lnum = 2, anchor_text = "c", body = "d", created_at = 2 })
    Store.mark_sent({ "1" }, "batch-1")

    local pending = Store.pending()
    assert.equals(1, #pending)
    assert.equals("2", pending[1].id)
  end)

  it("marks records sent with a shared batch id and timestamp", function()
    Store.add({ id = "1", file = "f.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.add({ id = "2", file = "f.lua", lnum = 2, end_lnum = 2, anchor_text = "c", body = "d", created_at = 2 })
    Store.mark_sent({ "1", "2" }, "batch-1")

    local records = Store.load()
    for _, rec in ipairs(records) do
      assert.equals("batch-1", rec.batch)
      assert.is_not_nil(rec.sent_at)
    end
    assert.equals(0, #Store.pending())
  end)

  it("returns only records for the given file", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.add({ id = "2", file = "b.lua", lnum = 1, end_lnum = 1, anchor_text = "c", body = "d", created_at = 2 })

    local for_a = Store.for_file("a.lua")
    assert.equals(1, #for_a)
    assert.equals("1", for_a[1].id)
  end)

  it("removes a record by id", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.remove("1")
    assert.equals(0, #Store.load())
  end)

  it("returns nil for a non-file buffer name instead of throwing", function()
    assert.is_nil(Store.relative_path("term://ls"))
    assert.is_nil(Store.relative_path("oil:///tmp/"))
    assert.is_nil(Store.relative_path(""))
  end)

  it("returns nil for a path whose directory does not exist", function()
    assert.is_nil(Store.relative_path("/no/such/directory/f.lua"))
  end)

  it("updates a record with a patch", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.update("1", { lnum = 5, anchor_text = "moved" })

    local rec = Store.load()[1]
    assert.equals(5, rec.lnum)
    assert.equals("moved", rec.anchor_text)
  end)

  local function resolutions_path()
    return vim.fs.joinpath(dir, ".git", "claude-annotations", "resolutions.jsonl")
  end

  local function write_resolution(row)
    local path = resolutions_path()
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    local lines = {}
    if vim.fn.filereadable(path) == 1 then
      lines = vim.fn.readfile(path)
    end
    table.insert(lines, vim.json.encode(row))
    vim.fn.writefile(lines, path)
  end

  it("merges the latest resolutions.jsonl row per id into load()", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.mark_sent({ "1" }, "batch-1")

    write_resolution({ id = "1", status = "unchanged", note = "first pass", ts = 100 })
    write_resolution({ id = "1", status = "changed", note = "renamed it", ts = 200, turn_seq = "0007" })
    Store._reset_cache()

    local rec = Store.load()[1]
    assert.is_not_nil(rec.resolution)
    assert.equals("changed", rec.resolution.status)
    assert.equals("renamed it", rec.resolution.note)
    assert.equals("0007", rec.resolution.turn_seq)
  end)

  it("resolved() returns only records with a merged resolution", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.add({ id = "2", file = "a.lua", lnum = 2, end_lnum = 2, anchor_text = "c", body = "d", created_at = 2 })
    Store.mark_sent({ "1", "2" }, "batch-1")
    write_resolution({ id = "1", status = "changed", note = "done", ts = 100 })
    Store._reset_cache()

    local resolved = Store.resolved()
    assert.equals(1, #resolved)
    assert.equals("1", resolved[1].id)
  end)

  it("dismiss removes the record and drops only its own resolutions.jsonl rows", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.add({ id = "2", file = "a.lua", lnum = 2, end_lnum = 2, anchor_text = "c", body = "d", created_at = 2 })
    Store.mark_sent({ "1", "2" }, "batch-1")
    write_resolution({ id = "1", status = "changed", note = "done", ts = 100 })
    write_resolution({ id = "2", status = "unchanged", note = "fine as is", ts = 100 })
    Store._reset_cache()

    Store.dismiss("1")

    local records = Store.load()
    assert.equals(1, #records)
    assert.equals("2", records[1].id)

    local remaining_rows = vim.fn.readfile(resolutions_path())
    assert.equals(1, #remaining_rows)
    local row = vim.json.decode(remaining_rows[1])
    assert.equals("2", row.id)
  end)

  it("resolve appends a manual row and updates the record in memory", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })

    Store.resolve("1", "didn't need a change")

    local rec = Store.load()[1]
    assert.equals("manual", rec.resolution.status)
    assert.equals("didn't need a change", rec.resolution.note)

    local rows = vim.fn.readfile(resolutions_path())
    assert.equals(1, #rows)
    local row = vim.json.decode(rows[1])
    assert.equals("1", row.id)
    assert.equals("manual", row.status)
  end)

  it("never writes a resolution key into annotations.json", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    write_resolution({ id = "1", status = "changed", note = "done", ts = 100 })
    Store._reset_cache()
    Store.load()
    Store.update("1", { lnum = 2 })

    local raw = table.concat(vim.fn.readfile(vim.fs.joinpath(dir, ".git", "claude-annotations", "annotations.json")), "\n")
    assert.is_nil(raw:find('"resolution"', 1, true))
  end)

  it("unresolve removes the resolutions.jsonl rows and clears sent_at/batch", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.mark_sent({ "1" }, "batch-1")
    write_resolution({ id = "1", status = "changed", note = "done", ts = 100 })
    Store._reset_cache()

    Store.unresolve("1")

    local rec = Store.load()[1]
    assert.is_nil(rec.resolution)
    assert.is_nil(rec.sent_at)
    assert.is_nil(rec.batch)
    assert.equals(1, #Store.pending())

    assert.equals(0, #vim.fn.readfile(resolutions_path()))
  end)
end)
