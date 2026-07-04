local assert = require("luassert")
local peek = require("app.review.ui.peek")

local function fc(path, status)
  return { path = path, status = status or "M" }
end

describe("peek._pad_left", function()
  it("prepends a leading cell to every line", function()
    local lines = peek._pad_left({ "a", " b", "" }, {})
    assert.same({ " a", "  b", " " }, lines)
  end)

  it("shifts col/end_col by 1 to match", function()
    local _, hl = peek._pad_left({ "x" }, { { line = 0, col = 0, end_col = 1, hl_group = "Foo" } })
    assert.same({ { line = 0, col = 1, end_col = 2, hl_group = "Foo" } }, hl)
  end)

  it("leaves a whole-line end_col of -1 alone (still means end of line)", function()
    local _, hl = peek._pad_left({ "x" }, { { line = 0, col = 0, end_col = -1, hl_group = "Comment" } })
    assert.equals(-1, hl[1].end_col)
    assert.equals(1, hl[1].col)
  end)
end)

describe("peek._dir_lines", function()
  it("lists dirs before files, alpha within groups", function()
    local entries = {
      { name = "b.lua", type = "file", path = "src/b.lua" },
      { name = "a.lua", type = "file", path = "src/a.lua" },
      { name = "nested", type = "dir", path = "src/nested" },
    }
    local lines = peek._dir_lines(entries, {})
    assert.same({
      "   nested/",
      "   a.lua",
      "   b.lua",
    }, lines)
  end)

  it("decorates changed entries with their status glyph, dims the rest", function()
    local entries = {
      { name = "a.lua", type = "file", path = "src/a.lua" },
      { name = "b.lua", type = "file", path = "src/b.lua" },
    }
    local changed = { ["src/a.lua"] = fc("src/a.lua", "M") }
    local lines, hl = peek._dir_lines(entries, changed)
    assert.equals("M  a.lua", lines[1])
    assert.equals("   b.lua", lines[2])
    assert.equals("DiffChange", hl[1].hl_group)
    assert.equals("Comment", hl[2].hl_group)
  end)

  it("renders (empty) for a dir with no entries", function()
    assert.same({ "(empty)" }, peek._dir_lines({}, {}))
  end)
end)

describe("peek._changeset_lines", function()
  local item = { changeset = { title = "feat x", pr_number = 42 }, _cs_idx = 2, _cs_total = 5 }

  it("headers with [i/n] title and PR number", function()
    local lines = peek._changeset_lines(item, nil, nil)
    assert.equals("[2/5] feat x  #42", lines[1])
  end)

  it("single-commit range shows the full message plus author/date", function()
    local commits = {
      { sha = "abc1234567", author = "A. Uthor", date = "2026-07-04", subject = "Do the thing", body = "Body line 1\nBody line 2" },
    }
    local lines = peek._changeset_lines(item, commits, nil)
    local text = table.concat(lines, "\n")
    assert.is_truthy(text:match("Do the thing"))
    assert.is_truthy(text:match("Body line 1\nBody line 2"))
    assert.is_truthy(text:match("A%. Uthor  2026%-07%-04"))
  end)

  it("multi-commit range shows an oneline-style list, no body", function()
    local commits = {
      { sha = "1111111", author = "A", date = "d", subject = "first", body = "" },
      { sha = "2222222", author = "A", date = "d", subject = "second", body = "" },
    }
    local lines = peek._changeset_lines(item, commits, nil)
    local text = table.concat(lines, "\n")
    assert.is_truthy(text:match("1111111  first"))
    assert.is_truthy(text:match("2222222  second"))
  end)

  it("no-ref (uncommitted) changeset has no commit section, just the header", function()
    local lines = peek._changeset_lines(item, nil, nil)
    assert.equals(2, #lines)
  end)

  it("appends the diffstat with +/- highlights when given", function()
    local lines, hl = peek._changeset_lines(item, nil, " f.lua | 3 +--\n")
    local text = table.concat(lines, "\n")
    assert.is_truthy(text:match("f%.lua | 3 %+%-%-"))
    local groups = {}
    for _, h in ipairs(hl) do
      groups[h.hl_group] = (groups[h.hl_group] or 0) + 1
    end
    assert.equals(1, groups["DiffAdd"])
    assert.equals(2, groups["DiffDelete"])
  end)
end)

describe("peek._float_geometry", function()
  -- A narrow left split standing in for the outline sidebar, beside a wide
  -- right split standing in for the diff panes.
  local narrow_win
  before_each(function()
    vim.cmd("only")
    vim.o.columns = 200
    vim.cmd("vsplit")
    vim.cmd("wincmd h")
    vim.api.nvim_win_set_width(0, 35)
    narrow_win = vim.api.nvim_get_current_win()
  end)

  local short_lines = { "a.lua", "b.lua" }
  local wide_line = string.rep("x", 60)

  it("positions past the narrow window's right edge, not inside it", function()
    local geo = peek._float_geometry(narrow_win, { wide_line })
    assert.is_not_nil(geo)
    assert.equals("editor", geo.relative)
    local win_pos = vim.api.nvim_win_get_position(narrow_win)
    assert.is_true(geo.col >= win_pos[2] + vim.api.nvim_win_get_width(narrow_win))
  end)

  it("is not clamped to the narrow window's width", function()
    local geo = peek._float_geometry(narrow_win, { wide_line })
    assert.is_true(geo.width > vim.api.nvim_win_get_width(narrow_win))
  end)

  it("sizes width to the longest line (plus a cell of padding), not a flat guess", function()
    local narrow_geo = peek._float_geometry(narrow_win, short_lines) -- "a.lua"/"b.lua", 5 cols
    local wide_geo = peek._float_geometry(narrow_win, { wide_line }) -- 60 cols
    assert.equals(20, narrow_geo.width) -- floored to the usable minimum
    assert.equals(#wide_line + 1, wide_geo.width)
    assert.is_true(wide_geo.width > narrow_geo.width)
  end)

  it("floors width at a usable minimum for very short content", function()
    local geo = peek._float_geometry(narrow_win, { "hi" })
    assert.equals(20, geo.width)
  end)

  it("caps width even when a line is longer than the cap", function()
    local geo = peek._float_geometry(narrow_win, { string.rep("x", 500) })
    assert.equals(100, geo.width)
  end)

  it("caps height to the content line count when it fits", function()
    local geo = peek._float_geometry(narrow_win, { "a", "b", "c" })
    assert.equals(3, geo.height)
  end)

  it("returns nil for an invalid window", function()
    vim.api.nvim_win_close(narrow_win, true)
    assert.is_nil(peek._float_geometry(narrow_win, 3))
  end)
end)

describe("peek.close", function()
  it("returns false when no peek float is open", function()
    assert.is_false(peek.close())
  end)

  it("closes an open peek float and reports it did", function()
    local bufnr, winid = vim.lsp.util.open_floating_preview({ "hi" }, "", {
      focus_id = "review_peek",
      focusable = true,
    })
    assert.is_true(vim.api.nvim_win_is_valid(winid))
    assert.is_true(peek.close())
    assert.is_false(vim.api.nvim_win_is_valid(winid))
    -- Idempotent: nothing left to close the second time.
    assert.is_false(peek.close())
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
end)
