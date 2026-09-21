local assert = require("luassert")
local Anchor = require("config.annotations.anchor")
local Store = require("config.annotations.store")

-- Concatenates every segment's text in a virt_line into one string, so a
-- spec can match on content without caring how the block splits it across
-- the bar/label/body/pad segments.
local function row_text(virt_line)
  local parts = {}
  for _, seg in ipairs(virt_line) do
    table.insert(parts, seg[1])
  end
  return table.concat(parts)
end

describe("Config.Annotations.Anchor", function()
  before_each(function()
    Store._reset_cache()
  end)

  it("renders a term://-named buffer without error", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "term://ls")
    local ok = pcall(Anchor.render, buf)
    assert.is_true(ok)
  end)

  it("renders an oil://-named buffer without error", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "oil:///tmp/")
    local ok = pcall(Anchor.render, buf)
    assert.is_true(ok)
  end)

  it("renders a buffer with no name without error", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local ok = pcall(Anchor.render, buf)
    assert.is_true(ok)
  end)
end)

describe("Config.Annotations.Anchor range tracking", function()
  local dir, prev_cwd

  local function file_lines(n)
    local lines = {}
    for i = 1, n do
      lines[i] = "line " .. i
    end
    return lines
  end

  before_each(function()
    prev_cwd = vim.uv.cwd()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
    vim.uv.chdir(dir)
    Store._reset_cache()
  end)

  after_each(function()
    vim.uv.chdir(prev_cwd)
    vim.fn.delete(dir, "rf")
  end)

  it("grows the stored range when an edit lands inside it", function()
    local abs = vim.fs.joinpath(dir, "f.lua")
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, abs)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({
      id = "r1",
      file = "f.lua",
      lnum = 3,
      end_lnum = 5,
      anchor_text = "line 3\nline 4\nline 5",
      body = "b",
      created_at = 0,
    })
    Anchor.render(buf)

    -- One new line inside the range (after buffer line 4, before line 5):
    -- the start extmark at line 3 doesn't move, the end extmark at line 5
    -- does, so the range grows by one without the start moving.
    vim.api.nvim_buf_set_lines(buf, 4, 4, false, { "inserted" })
    Anchor.sync(buf)

    local rec = Store.for_file("f.lua")[1]
    assert.equals(3, rec.lnum)
    assert.equals(6, rec.end_lnum)
  end)

  it("render_records draws into an untracked scratch buffer without letting sync write back", function()
    -- A picker preview: the file's lines in a buffer that carries no path.
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({
      id = "r1",
      file = "f.lua",
      lnum = 3,
      end_lnum = 5,
      anchor_text = "line 3\nline 4\nline 5",
      body = "b",
      created_at = 0,
    })
    Anchor.render_records(buf, Store.for_file("f.lua"))

    local marks = vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })
    assert.is_true(#marks > 0)

    -- Editing the scratch buffer and syncing must leave the store alone.
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted above" })
    Anchor.sync(buf)
    local rec = Store.for_file("f.lua")[1]
    assert.equals(3, rec.lnum)
    assert.equals(5, rec.end_lnum)
  end)

  it("shifts both ends of the range together for an edit above it", function()
    local abs = vim.fs.joinpath(dir, "f.lua")
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, abs)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({
      id = "r1",
      file = "f.lua",
      lnum = 3,
      end_lnum = 5,
      anchor_text = "line 3\nline 4\nline 5",
      body = "b",
      created_at = 0,
    })
    Anchor.render(buf)

    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted above" })
    Anchor.sync(buf)

    local rec = Store.for_file("f.lua")[1]
    assert.equals(4, rec.lnum)
    assert.equals(6, rec.end_lnum)
  end)

  it("combines annotations that end on the same line into one body block", function()
    local abs = vim.fs.joinpath(dir, "f.lua")
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, abs)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({ id = "r1", file = "f.lua", lnum = 3, end_lnum = 3, anchor_text = "line 3", body = "first", created_at = 1 })
    Store.add({ id = "r2", file = "f.lua", lnum = 3, end_lnum = 3, anchor_text = "line 3", body = "second", created_at = 2 })
    Anchor.render(buf)

    local marks = vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })
    local body_block
    for _, mark in ipairs(marks) do
      local details = mark[4]
      if details.virt_lines then
        body_block = details.virt_lines
      end
    end
    assert.is_not_nil(body_block)

    local rows = {}
    for _, virt_line in ipairs(body_block) do
      table.insert(rows, vim.trim(row_text(virt_line)))
    end
    -- label + body for "first", a blank separator, label + body for
    -- "second": one combined block, not two separate virt_lines extmarks.
    -- No window shows this buffer, so there's no gutter segment (see the
    -- "gutter" describe block below for that case) and the separator row is
    -- empty rather than bar-only.
    assert.equals(5, #rows)
    assert.matches("annotation · pending", rows[1])
    assert.matches("first", rows[2])
    assert.equals("", rows[3])
    assert.matches("annotation · pending", rows[4])
    assert.matches("second", rows[5])
  end)

  it("hangs a range annotation's body below the last line of the range", function()
    local abs = vim.fs.joinpath(dir, "f.lua")
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, abs)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({ id = "r1", file = "f.lua", lnum = 3, end_lnum = 6, anchor_text = "", body = "range", created_at = 1 })
    Anchor.render(buf)

    local marks = vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })
    local body_row
    for _, mark in ipairs(marks) do
      if mark[4].virt_lines then
        body_row = mark[2]
      end
    end
    -- 0-indexed row of line 6, the range end, not line 3 where it starts.
    assert.equals(5, body_row)
  end)

  it("connects a multi-line range's last sign into the block, or closes it when the block is hidden", function()
    local abs = vim.fs.joinpath(dir, "f.lua")
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, abs)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({ id = "r1", file = "f.lua", lnum = 3, end_lnum = 5, anchor_text = "x", body = "b", created_at = 1 })
    Anchor.render(buf)

    local function end_line_sign()
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })) do
        if mark[2] == 4 and mark[4].sign_text then -- row 4 (0-indexed) = buffer line 5, the range's end
          return vim.trim(mark[4].sign_text)
        end
      end
    end

    assert.equals("│", end_line_sign())

    Anchor.toggle_body()
    assert.equals("╵", end_line_sign())
    Anchor.toggle_body() -- restore the default for the specs after this one
  end)

  it("draws a resolved record's sign and note line", function()
    local abs = vim.fs.joinpath(dir, "f.lua")
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, abs)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({ id = "r1", file = "f.lua", lnum = 3, end_lnum = 3, anchor_text = "line 3", body = "rename this", created_at = 1 })
    Store.mark_sent({ "r1" }, "batch-1")

    local res_path = vim.fs.joinpath(dir, ".git", "claude-annotations", "resolutions.jsonl")
    vim.fn.mkdir(vim.fs.dirname(res_path), "p")
    vim.fn.writefile({ vim.json.encode({ id = "r1", status = "changed", note = "renamed it", ts = 1 }) }, res_path)
    Store._reset_cache()

    Anchor.render(buf)

    local marks = vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })
    local sign_mark, body_block
    for _, mark in ipairs(marks) do
      local details = mark[4]
      if details.sign_text then
        sign_mark = details
      end
      if details.virt_lines then
        body_block = details.virt_lines
      end
    end

    assert.is_not_nil(sign_mark)
    assert.equals("✓", vim.trim(sign_mark.sign_text))
    assert.equals("AnnotationResolvedSign", sign_mark.sign_hl_group)

    -- label, body, note: three rows, in that order.
    assert.equals(3, #body_block)
    assert.matches("annotation · changed", vim.trim(row_text(body_block[1])))
    assert.matches("rename this", vim.trim(row_text(body_block[2])))
    assert.matches("↳ renamed it", vim.trim(row_text(body_block[3])))
    -- No window shows this buffer, so there's no leading gutter segment: the
    -- note row's content is segment 1, the padding segment 2.
    assert.equals("AnnotationResolution", body_block[3][1][2])
  end)

  it("carries the AnnotationBlock background and a state label on every block line", function()
    local abs = vim.fs.joinpath(dir, "f.lua")
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, abs)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({ id = "pending", file = "f.lua", lnum = 1, end_lnum = 1, anchor_text = "line 1", body = "a", created_at = 1 })
    Store.add({ id = "sent", file = "f.lua", lnum = 2, end_lnum = 2, anchor_text = "line 2", body = "b", created_at = 2 })
    Store.mark_sent({ "sent" }, "batch-1")

    local res_path = vim.fs.joinpath(dir, ".git", "claude-annotations", "resolutions.jsonl")
    vim.fn.mkdir(vim.fs.dirname(res_path), "p")
    vim.fn.writefile({
      vim.json.encode({ id = "changed", status = "changed", note = "", ts = 1 }),
      vim.json.encode({ id = "unchanged", status = "unchanged", note = "", ts = 1 }),
      vim.json.encode({ id = "manual", status = "manual", note = "", ts = 1 }),
    }, res_path)

    for i, id in ipairs({ "changed", "unchanged", "manual" }) do
      Store.add({ id = id, file = "f.lua", lnum = 2 + i, end_lnum = 2 + i, anchor_text = "x", body = "c", created_at = 2 + i })
    end
    Store.mark_sent({ "changed", "unchanged", "manual" }, "batch-1")
    Store._reset_cache()

    Anchor.render(buf)

    local marks = vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })
    local labels = {}
    for _, mark in ipairs(marks) do
      local block = mark[4].virt_lines
      if block then
        for _, virt_line in ipairs(block) do
          local text = vim.trim(row_text(virt_line))
          if text:find("annotation ·", 1, true) or text:find("resolved by you", 1, true) then
            table.insert(labels, text)
          end
          -- every block line, not just labels, carries the padding chunk.
          local last = virt_line[#virt_line]
          assert.equals("AnnotationBlock", last[2])
        end
      end
    end

    table.sort(labels)
    assert.same({
      "annotation · changed",
      "annotation · pending",
      "annotation · resolved by you",
      "annotation · sent",
      "annotation · unchanged",
    }, labels)
  end)
end)

describe("Config.Annotations.Anchor gutter", function()
  local dir, prev_cwd, buf, win, prev_buf

  local function file_lines(n)
    local lines = {}
    for i = 1, n do
      lines[i] = "line " .. i
    end
    return lines
  end

  before_each(function()
    prev_cwd = vim.uv.cwd()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
    vim.uv.chdir(dir)
    Store._reset_cache()

    -- A real window with a known, fixed gutter width: signcolumn=yes is one
    -- column, number is `numberwidth` (default 4) more, so textoff = 5.
    win = vim.api.nvim_get_current_win()
    prev_buf = vim.api.nvim_win_get_buf(win)
    buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(win, buf)
    vim.wo[win].signcolumn = "yes"
    vim.wo[win].number = true
    vim.wo[win].relativenumber = false
    vim.wo[win].numberwidth = 4
    vim.api.nvim_buf_set_name(buf, vim.fs.joinpath(dir, "f.lua"))
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))
  end)

  after_each(function()
    vim.wo[win].signcolumn = "auto"
    vim.wo[win].number = false
    vim.wo[win].numberwidth = 4
    vim.api.nvim_win_set_buf(win, prev_buf)
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.uv.chdir(prev_cwd)
    vim.fn.delete(dir, "rf")
  end)

  it("gives every block row a leading gutter segment as wide as the window's textoff", function()
    Store.add({ id = "r1", file = "f.lua", lnum = 3, end_lnum = 3, anchor_text = "line 3", body = "rename this", created_at = 1 })
    Anchor.render(buf)

    local textoff = vim.fn.getwininfo(win)[1].textoff
    assert.is_true(textoff > 0)

    local marks = vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })
    local body_block
    for _, mark in ipairs(marks) do
      if mark[4].virt_lines then
        body_block = mark[4].virt_lines
      end
    end
    assert.is_not_nil(body_block)

    for _, virt_line in ipairs(body_block) do
      local gutter = virt_line[1]
      assert.equals(textoff, vim.fn.strdisplaywidth(gutter[1]))
      assert.matches("^AnnotationBlock", gutter[2])
    end

    -- One annotation, two rows: the label row's gutter is the branch glyph
    -- (at column 0 of the segment: this config's statuscolumn puts the sign
    -- column at the leftmost edge of the gutter, not after a fold column),
    -- and since the body row is also the last row of the block, its gutter
    -- is the closing glyph rather than a plain connector.
    assert.equals(2, #body_block)
    local label_gutter = body_block[1][1]
    assert.is_true(vim.startswith(label_gutter[1], "├"))
    assert.equals("AnnotationBlockSign", label_gutter[2])

    local last_gutter = body_block[2][1]
    assert.is_true(vim.startswith(last_gutter[1], "╵"))
    assert.equals("AnnotationBlockSign", last_gutter[2])
  end)

  it("branches each stacked annotation and closes the block with one range_end", function()
    Store.add({ id = "r1", file = "f.lua", lnum = 3, end_lnum = 3, anchor_text = "line 3", body = "first", created_at = 1 })
    Store.add({ id = "r2", file = "f.lua", lnum = 3, end_lnum = 3, anchor_text = "line 3", body = "second", created_at = 2 })
    Anchor.render(buf)

    local marks = vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })
    local body_block
    for _, mark in ipairs(marks) do
      if mark[4].virt_lines then
        body_block = mark[4].virt_lines
      end
    end
    assert.is_not_nil(body_block)

    -- label+body for "first", a connector-only separator, label+body for
    -- "second": ├, │, │, ├, ╵ (the last row closes regardless of row type).
    local glyphs = {}
    for _, virt_line in ipairs(body_block) do
      table.insert(glyphs, vim.trim(virt_line[1][1]))
    end
    assert.same({ "├", "│", "│", "├", "╵" }, glyphs)
  end)

  it("sets virt_lines_leftcol on the body extmark", function()
    Store.add({ id = "r1", file = "f.lua", lnum = 3, end_lnum = 3, anchor_text = "line 3", body = "rename this", created_at = 1 })
    Anchor.render(buf)

    local marks = vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })
    local found = false
    for _, mark in ipairs(marks) do
      if mark[4].virt_lines then
        found = true
        assert.is_true(mark[4].virt_lines_leftcol)
      end
    end
    assert.is_true(found)
  end)
end)
