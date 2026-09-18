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
end)
