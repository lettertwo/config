local assert = require("luassert")
local outline = require("app.review.ui.outline")

local function fc(path, opts)
  return vim.tbl_extend("keep", opts or {}, { path = path, status = "M", hunks = {}, changeset_id = "x" })
end

describe("outline._build_path_tree / _emit_tree_node", function()
  local files = {
    fc("lua/app/a.lua"),
    fc("lua/app/b.lua"),
    fc("lua/z.lua"),
    fc("README.md"),
  }
  local changed = {}
  for _, f in ipairs(files) do
    changed[f.path] = f
  end
  local paths = vim.tbl_map(function(f)
    return f.path
  end, files)

  local items = {}
  outline._emit_tree_node(outline._build_path_tree(paths, changed), nil, items)

  it("uses reserved __path/__file leaf keys", function()
    local tree = outline._build_path_tree({ "a/b.lua" }, { ["a/b.lua"] = files[1] })
    assert.equals("a/b.lua", tree.a["b.lua"].__path)
    assert.equals(files[1], tree.a["b.lua"].__file)
  end)

  it("orders dirs before files at each level, alpha within groups", function()
    -- top level: lua/ (dir) before README.md (file)
    assert.same(
      { "dir:lua", "dir:app", "file:lua/app/a.lua", "file:lua/app/b.lua", "file:lua/z.lua", "file:README.md" },
      vim.tbl_map(function(it)
        return it.type .. ":" .. (it.type == "dir" and it._name or it.change.path)
      end, items)
    )
  end)

  it("sets last flags for tree guides", function()
    -- README.md is the last top-level entry; z.lua is last within lua/
    assert.is_true(items[#items].last)
    local z
    for _, it in ipairs(items) do
      if it.type == "file" and it.change.path == "lua/z.lua" then
        z = it
      end
    end
    assert.is_true(z.last)
  end)

  it("links children to their parent dir items", function()
    local app_dir, a_file
    for _, it in ipairs(items) do
      if it.type == "dir" and it._name == "app" then
        app_dir = it
      end
      if it.type == "file" and it.change.path == "lua/app/a.lua" then
        a_file = it
      end
    end
    assert.equals(app_dir, a_file.parent)
  end)

  it("threads a full repo-relative path onto dir items", function()
    local lua_dir, app_dir
    for _, it in ipairs(items) do
      if it.type == "dir" and it._name == "lua" then
        lua_dir = it
      end
      if it.type == "dir" and it._name == "app" then
        app_dir = it
      end
    end
    assert.equals("lua", lua_dir.path)
    assert.equals("lua/app", app_dir.path)
  end)
end)

describe("outline._items_for", function()
  local cs1 = {
    id = "aaa",
    title = "feat a",
    files = { fc("a.lua", { changeset_id = "aaa" }) },
  }
  local cs2 = {
    id = "uncommitted",
    title = "Uncommitted Changes",
    current = true,
    files = { fc("b.lua", { changeset_id = "uncommitted" }), fc("c/d.lua", { changeset_id = "uncommitted" }) },
  }
  local docket = {
    changesets = { cs1, cs2 },
    files = { cs1.files[1], cs2.files[1], cs2.files[2] },
  }

  it("flat mode lists files in docket order", function()
    local items = outline._items_for(docket, "flat")
    assert.same({ "a.lua", "b.lua", "c/d.lua" }, vim.tbl_map(function(it)
      return it.change.path
    end, items))
  end)

  it("flat mode dedupes a path touched by several changesets, keeping the newest", function()
    local early = fc("a.lua", { changeset_id = "aaa" })
    local late = fc("a.lua", { changeset_id = "uncommitted" })
    local d = {
      changesets = {
        { id = "aaa", title = "feat a", files = { early } },
        { id = "uncommitted", title = "Uncommitted Changes", files = { late, fc("b.lua", { changeset_id = "uncommitted" }) } },
      },
      files = { early, late, fc("b.lua", { changeset_id = "uncommitted" }) },
    }
    local items = outline._items_for(d, "flat")
    assert.same({ "a.lua", "b.lua" }, vim.tbl_map(function(it)
      return it.change.path
    end, items))
    assert.equals(late, items[1].change)
  end)

  it("stack mode emits changeset headers with [i/n] context and scoped files", function()
    local items = outline._items_for(docket, "stack")
    assert.equals("changeset", items[1].type)
    assert.equals(1, items[1]._cs_idx)
    assert.equals(2, items[1]._cs_total)
    assert.equals("file", items[2].type)
    assert.equals(items[1], items[2].parent)
    assert.equals("changeset", items[3].type)
    assert.is_true(items[3].changeset.current)
    -- second changeset's files parented to ITS header, last flagged
    assert.equals(items[3], items[4].parent)
    assert.is_true(items[5].last)
    assert.equals(5, #items)
  end)

  it("stack mode defaults to base-first order when no order is given", function()
    local items = outline._items_for(docket, "stack")
    assert.equals(cs1, items[1].changeset)
    assert.equals(cs2, items[3].changeset)
  end)

  it("stack mode reverses headers to head-first order, recomputing idx/total/last", function()
    local items = outline._items_for(docket, "stack", "head-first")
    assert.equals("changeset", items[1].type)
    assert.equals(cs2, items[1].changeset)
    assert.equals(1, items[1]._cs_idx)
    assert.equals(2, items[1]._cs_total)
    assert.equals("changeset", items[4].type)
    assert.equals(cs1, items[4].changeset)
    assert.equals(2, items[4]._cs_idx)
    -- cs1's file is last overall in head-first order
    assert.is_true(items[5].last)
    assert.equals(5, #items)
  end)

  it("stack mode keeps base-first order when order is explicitly base-first", function()
    local items = outline._items_for(docket, "stack", "base-first")
    assert.equals(cs1, items[1].changeset)
    assert.equals(cs2, items[3].changeset)
  end)

  it("stack-tree mode also reverses headers to head-first order", function()
    local items = outline._items_for(docket, "stack-tree", "head-first")
    assert.equals(cs2, items[1].changeset)
  end)

  it("stack-tree mode nests each changeset's files as a tree", function()
    local items = outline._items_for(docket, "stack-tree")
    -- cs2: header, then dir c/ before file b.lua? dirs sort before files:
    -- header(cs1), a.lua, header(cs2), dir c, d.lua, b.lua
    assert.same(
      { "changeset", "file", "changeset", "dir", "file", "file" },
      vim.tbl_map(function(it)
        return it.type
      end, items)
    )
    assert.equals("c", items[4]._name)
    assert.equals("c/d.lua", items[5].change.path)
  end)

  it("returns an empty placeholder when there is nothing", function()
    local items = outline._items_for({ changesets = {}, files = {} }, "flat")
    assert.equals(1, #items)
    assert.equals("empty", items[1].type)
  end)
end)

describe("outline._find_row", function()
  local early = fc("a.lua", { changeset_id = "aaa" })
  local late = fc("a.lua", { changeset_id = "uncommitted" })
  local docket = {
    changesets = {
      { id = "aaa", title = "feat a", files = { early } },
      { id = "uncommitted", title = "Uncommitted Changes", files = { late, fc("b.lua", { changeset_id = "uncommitted" }) } },
    },
    files = { early, late, fc("b.lua", { changeset_id = "uncommitted" }) },
  }

  it("returns nil for a nil file", function()
    assert.is_nil(outline._find_row(outline._items_for(docket, "flat"), nil, "flat"))
  end)

  it("flat mode matches by path, even when current file is a superseded duplicate", function()
    local items = outline._items_for(docket, "flat")
    -- flat dedupes a.lua to `late`; `early` is a different object for the same path.
    assert.equals(1, outline._find_row(items, early, "flat"))
    assert.equals(1, outline._find_row(items, late, "flat"))
  end)

  it("tree mode matches by path", function()
    local items = outline._items_for(docket, "tree")
    local row = outline._find_row(items, early, "tree")
    assert.equals("a.lua", items[row].change.path)
  end)

  it("stack mode matches by object identity, not just path", function()
    local items = outline._items_for(docket, "stack")
    assert.equals(2, outline._find_row(items, early, "stack"))
    assert.equals(4, outline._find_row(items, late, "stack"))
  end)

  it("returns nil when the file isn't among the displayed items", function()
    local items = outline._items_for(docket, "flat")
    assert.is_nil(outline._find_row(items, fc("missing.lua", { changeset_id = "aaa" }), "flat"))
  end)
end)
