local assert = require("luassert")

describe("diff._sbs_annotations", function()
  -- Plenary's child nvim runs --noplugin; word.compute needs codediff.
  vim.cmd.packadd("codediff.nvim")
  local diff = require("app.review.ui.diff")

  local function ctx(text, o, n)
    return { kind = "ctx", text = text, old_lnum = o, new_lnum = n }
  end
  local function add(text, n)
    return { kind = "add", text = text, new_lnum = n }
  end
  local function del(text, o)
    return { kind = "del", text = text, old_lnum = o }
  end

  local function filler_total(fillers)
    local t = 0
    for _, f in ipairs(fillers) do
      t = t + f.count
    end
    return t
  end

  -- Line-count parity: real lines + fillers must match across sides. (An
  -- empty side still renders one blank buffer line — a known, POC-accepted
  -- off-by-one for added/deleted files.)
  local function assert_parity(ann, old_lines, new_lines)
    assert.equals(#old_lines + filler_total(ann.fillers_l), #new_lines + filler_total(ann.fillers_r))
  end

  it("asymmetric change: filler on the shorter side below its last del row", function()
    local old_lines = { "a", "b", "old1", "c", "d", "e", "f", "g" }
    local new_lines = { "a", "b", "new1", "new2", "new3", "c", "d", "e", "f", "g" }
    local hunks = {
      {
        old_start = 1,
        old_count = 6,
        new_start = 1,
        new_count = 8,
        lines = {
          ctx("a", 1, 1),
          ctx("b", 2, 2),
          del("old1", 3),
          add("new1", 3),
          add("new2", 4),
          add("new3", 5),
          ctx("c", 4, 6),
          ctx("d", 5, 7),
          ctx("e", 6, 8),
        },
      },
    }
    local ann = diff._sbs_annotations(hunks, old_lines, new_lines)

    assert.same({ { row = 2, count = 2, above = false } }, ann.fillers_l)
    assert.same({}, ann.fillers_r)
    assert_parity(ann, old_lines, new_lines)

    assert.same({ { s = 0, e = 5, first_diff = 2, last_diff = 2 } }, ann.hunk_rows_l)
    assert.same({ { s = 0, e = 7, first_diff = 2, last_diff = 4 } }, ann.hunk_rows_r)

    -- Change-pair line: bg extmarks per side plus word-diff overlays at 1000.
    local function count(exts, pred)
      local c = 0
      for _, e in ipairs(exts) do
        if pred(e) then
          c = c + 1
        end
      end
      return c
    end
    -- Char-level bg marks (one per line; the hl_eol fill mark is separate).
    assert.equals(1, count(ann.exts_l, function(e)
      return e.opts.hl_group == "ReviewDiffDelete" and e.opts.end_col ~= nil and not e.opts.hl_eol
    end))
    assert.equals(3, count(ann.exts_r, function(e)
      return e.opts.hl_group == "ReviewDiffAdd" and e.opts.end_col ~= nil and not e.opts.hl_eol
    end))
    assert.is_true(count(ann.exts_l, function(e)
      return e.opts.priority == 1000
    end) > 0)
    assert.is_true(count(ann.exts_r, function(e)
      return e.opts.priority == 1000
    end) > 0)
    -- Paired change gets the change sign on both sides; unpaired adds don't.
    assert.equals(1, count(ann.exts_l, function(e)
      return e.opts.sign_hl_group == "ReviewSignGutterDeleteChange"
    end))
    assert.equals(1, count(ann.exts_r, function(e)
      return e.opts.sign_hl_group == "ReviewSignGutterAddChange"
    end))
    assert.equals(2, count(ann.exts_r, function(e)
      return e.opts.sign_hl_group == "ReviewSignGutterAdd"
    end))
  end)

  it("deletion at line 1: filler lands above row 0 of the non-empty side", function()
    local old_lines = { "x", "a", "b", "c" }
    local new_lines = { "a", "b", "c" }
    local hunks = {
      {
        old_start = 1,
        old_count = 4,
        new_start = 1,
        new_count = 3,
        lines = { del("x", 1), ctx("a", 2, 1), ctx("b", 3, 2), ctx("c", 4, 3) },
      },
    }
    local ann = diff._sbs_annotations(hunks, old_lines, new_lines)
    assert.same({ { row = 0, count = 1, above = true } }, ann.fillers_r)
    assert.same({}, ann.fillers_l)
    assert_parity(ann, old_lines, new_lines)
  end)

  it("added file: empty left side anchors fillers below its blank row", function()
    local old_lines = {}
    local new_lines = { "l1", "l2" }
    local hunks = {
      {
        old_start = 0,
        old_count = 0,
        new_start = 1,
        new_count = 2,
        lines = { add("l1", 1), add("l2", 2) },
      },
    }
    local ann = diff._sbs_annotations(hunks, old_lines, new_lines)
    assert.same({ { row = 0, count = 2, above = false } }, ann.fillers_l)
    assert.same({ { s = 0, e = 0, first_diff = 0, last_diff = 0 } }, ann.hunk_rows_l)
    assert.same({ { s = 0, e = 1, first_diff = 0, last_diff = 1 } }, ann.hunk_rows_r)
    assert_parity(ann, old_lines, new_lines)
  end)

  it("trailing pure-del: filler below the last row of the new side", function()
    local old_lines = { "a", "b", "c", "d", "e" }
    local new_lines = { "a", "b", "c" }
    local hunks = {
      {
        old_start = 1,
        old_count = 5,
        new_start = 1,
        new_count = 3,
        lines = { ctx("a", 1, 1), ctx("b", 2, 2), ctx("c", 3, 3), del("d", 4), del("e", 5) },
      },
    }
    local ann = diff._sbs_annotations(hunks, old_lines, new_lines)
    assert.same({ { row = 2, count = 2, above = false } }, ann.fillers_r)
    assert_parity(ann, old_lines, new_lines)
    assert.same({ { s = 0, e = 4, first_diff = 3, last_diff = 4 } }, ann.hunk_rows_l)
  end)

  it("attributed pickers classify lines by sub-diff coordinate membership", function()
    -- Whole file with one unstaged add (worktree lnum 5) and one staged
    -- del (HEAD lnum 3).
    local file = {
      path = "f.lua",
      unstaged = { hunks = { { lines = { { kind = "add", text = "u", new_lnum = 5 } } } } },
      staged_change = { hunks = { { lines = { { kind = "del", text = "s", old_lnum = 3 } } } } },
    }
    local pick_add, pick_del = diff._group_pickers("attributed", file)
    -- Unstaged add keeps plain colors; any other whole-view add is staged.
    assert.equals("ReviewDiffAdd", pick_add(5).add)
    assert.equals("ReviewDiffStagedAdd", pick_add(6).add)
    -- Staged del gets staged colors; any other whole-view del is unstaged.
    assert.equals("ReviewDiffStagedDelete", pick_del(3).del)
    assert.equals("ReviewDiffDelete", pick_del(4).del)

    -- staged mode: everything staged; plain mode: everything plain.
    local sa, sd = diff._group_pickers("staged", file)
    assert.equals("ReviewDiffStagedAdd", sa(5).add)
    assert.equals("ReviewDiffStagedDelete", sd(4).del)
    local pa, pd = diff._group_pickers("plain", file)
    assert.equals("ReviewDiffAdd", pa(99).add)
    assert.equals("ReviewDiffDelete", pd(99).del)
  end)

  it("threads picked groups through the sbs walk", function()
    local old_lines = { "a", "old", "b" }
    local new_lines = { "a", "new", "b" }
    local hunks = {
      {
        old_start = 1,
        old_count = 3,
        new_start = 1,
        new_count = 3,
        lines = {
          { kind = "ctx", text = "a", old_lnum = 1, new_lnum = 1 },
          { kind = "del", text = "old", old_lnum = 2 },
          { kind = "add", text = "new", new_lnum = 2 },
          { kind = "ctx", text = "b", old_lnum = 3, new_lnum = 3 },
        },
      },
    }
    local staged_grp = { add = "SA", del = "SD", add_word = "SAW", del_word = "SDW", sign_add = "sa", sign_del = "sd", sign_change = "sc" }
    local ann = diff._sbs_annotations(hunks, old_lines, new_lines, {
      pick_add = function()
        return staged_grp
      end,
      pick_del = function()
        return staged_grp
      end,
    })
    local found_add, found_del = false, false
    for _, e in ipairs(ann.exts_r) do
      if e.opts.hl_group == "SA" then
        found_add = true
      end
    end
    for _, e in ipairs(ann.exts_l) do
      if e.opts.hl_group == "SD" then
        found_del = true
      end
    end
    assert.is_true(found_add)
    assert.is_true(found_del)
  end)

  it("multi-hunk: inter-hunk gaps are equal per side, so folds pair by index", function()
    -- old: 20 ctx lines with a change at 5 (1<->1) and one at 15 (2 dels).
    local old_lines, new_lines = {}, {}
    for i = 1, 20 do
      old_lines[i] = "line " .. i
    end
    -- new: line5 changed; lines 15,16 deleted.
    for i = 1, 20 do
      if i == 5 then
        new_lines[#new_lines + 1] = "LINE 5"
      elseif i ~= 15 and i ~= 16 then
        new_lines[#new_lines + 1] = "line " .. i
      end
    end
    local hunks = {
      {
        old_start = 2,
        old_count = 7,
        new_start = 2,
        new_count = 7,
        lines = {
          ctx("line 2", 2, 2),
          ctx("line 3", 3, 3),
          ctx("line 4", 4, 4),
          del("line 5", 5),
          add("LINE 5", 5),
          ctx("line 6", 6, 6),
          ctx("line 7", 7, 7),
          ctx("line 8", 8, 8),
        },
      },
      {
        old_start = 12,
        old_count = 8,
        new_start = 12,
        new_count = 6,
        lines = {
          ctx("line 12", 12, 12),
          ctx("line 13", 13, 13),
          ctx("line 14", 14, 14),
          del("line 15", 15),
          del("line 16", 16),
          ctx("line 17", 17, 15),
          ctx("line 18", 18, 16),
          ctx("line 19", 19, 17),
        },
      },
    }
    local ann = diff._sbs_annotations(hunks, old_lines, new_lines)
    assert.equals(#ann.hunk_rows_l, #ann.hunk_rows_r)
    -- Leading gap and each inter-hunk gap have equal line counts per side —
    -- the invariant the index-paired fold sync relies on.
    assert.equals(ann.hunk_rows_l[1].s, ann.hunk_rows_r[1].s)
    for i = 1, #ann.hunk_rows_l - 1 do
      assert.equals(
        ann.hunk_rows_l[i + 1].s - ann.hunk_rows_l[i].e,
        ann.hunk_rows_r[i + 1].s - ann.hunk_rows_r[i].e
      )
    end
    assert_parity(ann, old_lines, new_lines)
  end)

  it("file grown past the hunk's trailing context: shorter side gets a tail filler", function()
    -- The hunk describes a diff against a 5-line blob; the live blob has
    -- since grown by 3 lines past where the hunk's context ends. Nothing in
    -- any hunk is wrong, but the two sides' unchanged tails no longer run
    -- the same length.
    local old_lines = { "a", "b", "c", "d", "e" }
    local new_lines = { "a", "B", "c", "d", "e", "f", "g", "h" }
    local hunks = {
      {
        old_start = 1,
        old_count = 3,
        new_start = 1,
        new_count = 3,
        lines = { ctx("a", 1, 1), del("b", 2), add("B", 2), ctx("c", 3, 3) },
      },
    }
    local ann = diff._sbs_annotations(hunks, old_lines, new_lines)
    assert_parity(ann, old_lines, new_lines)
    assert.same({ { row = 4, count = 3, above = false } }, ann.fillers_l)
  end)

  it("unpaired add rows get a whole-line word mark; paired rows keep partial marks", function()
    local old_lines = { "ctx1", "foo old bar", "ctx2" }
    local new_lines = { "ctx1", "foo new bar", "added2", "ctx2" }
    local hunks = {
      {
        old_start = 1,
        old_count = 3,
        new_start = 1,
        new_count = 4,
        lines = {
          ctx("ctx1", 1, 1),
          del("foo old bar", 2),
          add("foo new bar", 2),
          add("added2", 3),
          ctx("ctx2", 3, 4),
        },
      },
    }
    local ann = diff._sbs_annotations(hunks, old_lines, new_lines)

    local function word_marks(exts, row)
      local out = {}
      for _, e in ipairs(exts) do
        if e.row == row and e.opts.priority == 1000 then
          table.insert(out, e)
        end
      end
      return out
    end

    -- "foo new bar" (row 1) is paired against "foo old bar": the word diff
    -- covers only the changed word, not the whole 11-char line.
    local paired_marks = word_marks(ann.exts_r, 1)
    assert.is_true(#paired_marks > 0)
    for _, m in ipairs(paired_marks) do
      assert.is_true(m.opts.end_col - m.col < #"foo new bar")
    end

    -- "added2" (row 2) has no del counterpart: one mark spanning the whole line.
    local unpaired_marks = word_marks(ann.exts_r, 2)
    assert.equals(1, #unpaired_marks)
    assert.equals(0, unpaired_marks[1].col)
    assert.equals(#"added2", unpaired_marks[1].opts.end_col)
  end)

  it("a whole-file status suppresses the unpaired whole-line marks", function()
    local old_lines = { "a", "b" }
    local new_lines = {}
    local hunks = {
      {
        old_start = 1,
        old_count = 2,
        new_start = 0,
        new_count = 0,
        lines = { del("a", 1), del("b", 2) },
      },
    }

    local function count_word_marks(exts)
      local c = 0
      for _, e in ipairs(exts) do
        if e.opts.priority == 1000 then
          c = c + 1
        end
      end
      return c
    end

    local deleted_file = diff._sbs_annotations(hunks, old_lines, new_lines, { status = "D" })
    assert.equals(0, count_word_marks(deleted_file.exts_l))

    -- Without the status guard, the same pure-del hunk gets whole-line marks
    -- (a genuine unpaired del inside an otherwise-modified file).
    local mid_file = diff._sbs_annotations(hunks, old_lines, new_lines)
    assert.is_true(count_word_marks(mid_file.exts_l) > 0)
  end)
end)

describe("diff._build_virt_chunks: innermost treesitter capture wins", function()
  local diff = require("app.review.ui.diff")

  it("a call name and a string escape both pick the last, most specific capture", function()
    local text = 'let s = Foo::new("a\\n");'
    local per_line = diff._ts_highlights_for_lines({ text }, "rust")
    local chunks = diff._build_virt_chunks(text, per_line[0], nil, nil)

    local function group_for(seg_text)
      for _, c in ipairs(chunks) do
        if c[1] == seg_text then
          return c[2]
        end
      end
    end

    -- The call name overlaps a plain @variable capture and a @function.call
    -- one at the same span; the highlighter draws the latter last.
    local new_grp = group_for("new")
    assert.is_table(new_grp)
    assert.equals("@function.call.rust", new_grp[2])

    -- The escape sequence nests inside the wider @string capture.
    local esc_grp = group_for("\\n")
    assert.is_table(esc_grp)
    assert.equals("@string.escape.rust", esc_grp[2])
  end)

  it("a word-diff segment keeps its syntax group alongside the word group", function()
    local text = 'let s = Foo::new("a\\n");'
    local per_line = diff._ts_highlights_for_lines({ text }, "rust")
    local wd_hl = { { col = 13, end_col = 16, hl_group = "ReviewDiffDeleteWord" } }
    local chunks = diff._build_virt_chunks(text, per_line[0], wd_hl, nil)

    local new_grp
    for _, c in ipairs(chunks) do
      if c[1] == "new" then
        new_grp = c[2]
      end
    end
    assert.is_table(new_grp)
    assert.equals("ReviewDiffDeleteWord", new_grp[1])
    assert.equals("@function.call.rust", new_grp[2])
  end)
end)

describe("diff.render alignment re-acquire", function()
  vim.cmd.packadd("codediff.nvim")
  local diff = require("app.review.ui.diff")
  local git = require("app.review.diff.git")

  -- Replaces git.show for the life of one test: HEAD always answers with
  -- `head_content`; WORKTREE answers with the next entry of `worktree_reads`
  -- (the last entry repeats once exhausted, simulating a file that never
  -- settles). Returns a call counter and a restore function.
  local function stub_show(head_content, worktree_reads)
    local orig = git.show
    local worktree_calls = 0
    git.show = function(_, ref, _, cb)
      if ref == "HEAD" then
        cb(head_content, nil)
        return
      end
      worktree_calls = worktree_calls + 1
      cb(worktree_reads[worktree_calls] or worktree_reads[#worktree_reads], nil)
    end
    return function()
      return worktree_calls
    end, function()
      git.show = orig
    end
  end

  -- A single-hunk change (line 2, "b" -> "B") against a 5-line HEAD blob.
  -- Trailing context after the hunk is lines 4-5, so a consistent worktree
  -- read must also total 5 lines.
  local head_content = "a\nb\nc\nd\ne"
  local hunks = {
    {
      old_start = 1,
      old_count = 3,
      new_start = 1,
      new_count = 3,
      lines = {
        { kind = "ctx", text = "a", old_lnum = 1, new_lnum = 1 },
        { kind = "del", text = "b", old_lnum = 2 },
        { kind = "add", text = "B", new_lnum = 2 },
        { kind = "ctx", text = "c", old_lnum = 3, new_lnum = 3 },
      },
    },
  }

  local function make_view()
    return diff.new({ win = vim.api.nvim_get_current_win() })
  end

  it("recovers on one retry when the first worktree read races a writer", function()
    -- First read catches the file mid-write (truncated to 3 lines); the
    -- second, retried read lands after the writer finishes.
    local calls, restore = stub_show(head_content, { "a\nB\nc", "a\nB\nc\nd\ne" })
    local dv = make_view()
    local done = false
    dv:render({ path = "f.txt", hunks = hunks }, "/tmp", function()
      done = true
    end)
    restore()
    assert.is_true(done)
    assert.equals(2, calls())
    assert.equals(5, vim.api.nvim_buf_line_count(dv.right.bufnr))
    dv:destroy()
  end)

  it("renders whatever it has once the one retry is spent", function()
    -- The worktree read never settles; every attempt sees the same
    -- mismatched, truncated content.
    local calls, restore = stub_show(head_content, { "a\nB\nc" })
    local dv = make_view()
    local done = false
    dv:render({ path = "f.txt", hunks = hunks }, "/tmp", function()
      done = true
    end)
    restore()
    assert.is_true(done)
    -- One initial read plus exactly one retry, never more.
    assert.equals(2, calls())
    assert.equals(3, vim.api.nvim_buf_line_count(dv.right.bufnr))
    dv:destroy()
  end)
end)

describe("diff._render_inline lnums (old/new statuscolumn data)", function()
  vim.cmd.packadd("codediff.nvim")
  local diff = require("app.review.ui.diff")
  local git = require("app.review.diff.git")

  -- One-shot git.show stub: HEAD answers with old_content, anything else
  -- (WORKTREE) with new_content. No retry simulation — every fixture here
  -- gives old/new lengths that exactly cover their hunks, so the
  -- tail-length re-acquire in DiffView:render never triggers.
  local function stub_show(old_content, new_content)
    local orig = git.show
    git.show = function(_, ref, _, cb)
      cb(ref == "HEAD" and old_content or new_content, nil)
    end
    return function()
      git.show = orig
    end
  end

  local function make_view()
    return diff.new({ win = vim.api.nvim_get_current_win() })
  end

  local function render(file, old_content, new_content)
    local restore = stub_show(old_content, new_content)
    local dv = make_view()
    local done = false
    dv:render(file, "/tmp", function()
      done = true
    end)
    restore()
    assert.is_true(done)
    return dv
  end

  it("mixed hunk: context, paired change, pure del, pure add", function()
    local hunks = {
      {
        old_start = 1,
        old_count = 10,
        new_start = 1,
        new_count = 10,
        lines = {
          { kind = "ctx", text = "a", old_lnum = 1, new_lnum = 1 },
          { kind = "ctx", text = "b", old_lnum = 2, new_lnum = 2 },
          { kind = "del", text = "OLD1", old_lnum = 3 },
          { kind = "add", text = "NEW1", new_lnum = 3 },
          { kind = "ctx", text = "c", old_lnum = 4, new_lnum = 4 },
          { kind = "ctx", text = "d", old_lnum = 5, new_lnum = 5 },
          { kind = "del", text = "OLDX", old_lnum = 6 },
          { kind = "ctx", text = "e", old_lnum = 7, new_lnum = 6 },
          { kind = "add", text = "ADDED", new_lnum = 7 },
          { kind = "ctx", text = "f", old_lnum = 8, new_lnum = 8 },
          { kind = "ctx", text = "g", old_lnum = 9, new_lnum = 9 },
          { kind = "ctx", text = "h", old_lnum = 10, new_lnum = 10 },
        },
      },
    }
    local dv = render(
      { path = "f.txt", hunks = hunks },
      "a\nb\nOLD1\nc\nd\nOLDX\ne\nf\ng\nh",
      "a\nb\nNEW1\nc\nd\ne\nADDED\nf\ng\nh"
    )
    local lnums = dv.right.lnums
    assert.is_false(lnums.deleted)
    assert.equals(2, lnums.width) -- max(10, 10) → "10"

    -- Context rows carry the old number; add rows (NEW1@3, ADDED@7) don't.
    assert.same({ [1] = 1, [2] = 2, [4] = 4, [5] = 5, [6] = 7, [8] = 8, [9] = 9, [10] = 10 }, lnums.old_of)

    -- Paired change: OLD1's del virt anchors above row 2 (NEW1's row).
    assert.equals(1, #lnums.virt_old[2])
    assert.equals(3, lnums.virt_old[2][1].lnum)
    -- Pure del: OLDX anchors above row 5 (ctx "e"'s row, the next segment).
    assert.equals(1, #lnums.virt_old[5])
    assert.equals(6, lnums.virt_old[5][1].lnum)
    -- Pure add (ADDED) contributes no del entries. del_virts[anchor] is
    -- unconditionally created per change segment (see _render_inline), so
    -- virt_old[6] may exist as an empty list rather than nil — either way,
    -- an empty virt_lines extmark never renders, so v:virtnum never goes
    -- negative on that row and the statuscolumn never looks it up.
    assert.equals(0, #(lnums.virt_old[6] or {}))

    dv:destroy()
  end)

  it("del-only hunk at top of file", function()
    local hunks = {
      {
        old_start = 1,
        old_count = 3,
        new_start = 1,
        new_count = 2,
        lines = {
          { kind = "del", text = "x", old_lnum = 1 },
          { kind = "ctx", text = "a", old_lnum = 2, new_lnum = 1 },
          { kind = "ctx", text = "b", old_lnum = 3, new_lnum = 2 },
        },
      },
    }
    local dv = render({ path = "f.txt", hunks = hunks }, "x\na\nb", "a\nb")
    local lnums = dv.right.lnums
    assert.same({ [1] = 2, [2] = 3 }, lnums.old_of)
    -- Anchor is the next ctx line ("a", new_lnum 1) → row 0, above the
    -- first real row.
    assert.equals(1, #lnums.virt_old[0])
    assert.equals(1, lnums.virt_old[0][1].lnum)
    dv:destroy()
  end)

  it("trailing dels plus above-dels on the last row: visual order (above then below)", function()
    local hunks = {
      {
        old_start = 1,
        old_count = 5,
        new_start = 1,
        new_count = 3,
        lines = {
          { kind = "ctx", text = "a", old_lnum = 1, new_lnum = 1 },
          { kind = "ctx", text = "b", old_lnum = 2, new_lnum = 2 },
          { kind = "del", text = "OLDLAST", old_lnum = 3 },
          { kind = "add", text = "NEWLAST", new_lnum = 3 },
          { kind = "del", text = "TAIL1", old_lnum = 4 },
          { kind = "del", text = "TAIL2", old_lnum = 5 },
        },
      },
    }
    local dv = render(
      { path = "f.txt", hunks = hunks },
      "a\nb\nOLDLAST\nTAIL1\nTAIL2",
      "a\nb\nNEWLAST"
    )
    local lnums = dv.right.lnums
    local last_row = 2 -- #new_lines - 1
    assert.equals(3, #lnums.virt_old[last_row])
    -- Above-anchored OLDLAST first, then the trailing TAIL1/TAIL2 in file order.
    assert.equals(3, lnums.virt_old[last_row][1].lnum)
    assert.equals(4, lnums.virt_old[last_row][2].lnum)
    assert.equals(5, lnums.virt_old[last_row][3].lnum)
    dv:destroy()
  end)

  it("deleted file: buffer holds the old file, lnums flags it and carries no old_of/virt_old", function()
    local hunks = {
      {
        old_start = 1,
        old_count = 3,
        new_start = 0,
        new_count = 0,
        lines = {
          { kind = "del", text = "a", old_lnum = 1 },
          { kind = "del", text = "b", old_lnum = 2 },
          { kind = "del", text = "c", old_lnum = 3 },
        },
      },
    }
    local dv = render({ path = "f.txt", status = "D", hunks = hunks }, "a\nb\nc", "")
    local lnums = dv.right.lnums
    assert.is_true(lnums.deleted)
    assert.same({}, lnums.old_of)
    assert.same({}, lnums.virt_old)
    assert.equals(1, lnums.width) -- #tostring(3)
    dv:destroy()
  end)

  it("added file: old_of stays empty so the old column blanks throughout", function()
    local hunks = {
      {
        old_start = 0,
        old_count = 0,
        new_start = 1,
        new_count = 2,
        lines = {
          { kind = "add", text = "l1", new_lnum = 1 },
          { kind = "add", text = "l2", new_lnum = 2 },
        },
      },
    }
    local dv = render({ path = "f.txt", status = "A", hunks = hunks }, "", "l1\nl2")
    local lnums = dv.right.lnums
    assert.is_false(lnums.deleted)
    assert.same({}, lnums.old_of)
    -- The whole-file add is one change segment anchored at new_lnum 1, so
    -- del_virts[1] (and virt_old[0]) exists as an empty list rather than
    -- nil — harmless, since an empty virt_lines extmark never renders (see
    -- the mixed-hunk case above for the same nuance).
    assert.equals(0, #(lnums.virt_old[0] or {}))
    assert.equals(1, lnums.width) -- #tostring(2)
    dv:destroy()
  end)
end)

describe("diff._render_inline: unpaired-line word emphasis (real buffer)", function()
  vim.cmd.packadd("codediff.nvim")
  local diff = require("app.review.ui.diff")
  local git = require("app.review.diff.git")

  local function stub_show(old_content, new_content)
    local orig = git.show
    git.show = function(_, ref, _, cb)
      cb(ref == "HEAD" and old_content or new_content, nil)
    end
    return function()
      git.show = orig
    end
  end

  local function render(file, old_content, new_content)
    local restore = stub_show(old_content, new_content)
    local dv = diff.new({ win = vim.api.nvim_get_current_win() })
    local done = false
    dv:render(file, "/tmp", function()
      done = true
    end)
    restore()
    assert.is_true(done)
    return dv
  end

  local function word_marks(bufnr, row)
    local marks =
      vim.api.nvim_buf_get_extmarks(bufnr, require("app.review.ui.signs").ns, { row, 0 }, { row, -1 }, { details = true })
    local out = {}
    for _, m in ipairs(marks) do
      if m[4].priority == 1000 then
        table.insert(out, m[4])
      end
    end
    return out
  end

  it("a pure-add run inside a modified file gets a whole-line word mark", function()
    local hunks = {
      {
        old_start = 1,
        old_count = 2,
        new_start = 1,
        new_count = 3,
        lines = {
          { kind = "ctx", text = "a", old_lnum = 1, new_lnum = 1 },
          { kind = "add", text = "brand new", new_lnum = 2 },
          { kind = "ctx", text = "b", old_lnum = 2, new_lnum = 3 },
        },
      },
    }
    local dv = render({ path = "f.txt", hunks = hunks }, "a\nb", "a\nbrand new\nb")
    local marks = word_marks(dv.right.bufnr, 1)
    assert.equals(1, #marks)
    assert.equals(#"brand new", marks[1].end_col)
    dv:destroy()
  end)

  it("an added file gets no whole-line word marks", function()
    local hunks = {
      {
        old_start = 0,
        old_count = 0,
        new_start = 1,
        new_count = 2,
        lines = {
          { kind = "add", text = "l1", new_lnum = 1 },
          { kind = "add", text = "l2", new_lnum = 2 },
        },
      },
    }
    local dv = render({ path = "f.txt", status = "A", hunks = hunks }, "", "l1\nl2")
    assert.equals(0, #word_marks(dv.right.bufnr, 0))
    assert.equals(0, #word_marks(dv.right.bufnr, 1))
    dv:destroy()
  end)

  it("a pure-del run's virt_line chunk is one whole-line word-tier segment", function()
    local hunks = {
      {
        old_start = 1,
        old_count = 2,
        new_start = 1,
        new_count = 1,
        lines = {
          { kind = "del", text = "gone entirely", old_lnum = 1 },
          { kind = "ctx", text = "a", old_lnum = 2, new_lnum = 1 },
        },
      },
    }
    local dv = render({ path = "f.txt", hunks = hunks }, "gone entirely\na", "a")
    local marks = vim.api.nvim_buf_get_extmarks(dv.right.bufnr, require("app.review.ui.signs").ns, { 0, 0 }, { 0, -1 }, { details = true })
    local virt_lines
    for _, m in ipairs(marks) do
      if m[4].virt_lines then
        virt_lines = m[4].virt_lines
      end
    end
    assert.is_not_nil(virt_lines)
    -- One text chunk for the whole 13-char line (word tier), plus the
    -- padding chunk build_virt_chunks always appends.
    local chunks = virt_lines[1]
    assert.equals(2, #chunks)
    assert.equals("gone entirely", chunks[1][1])
    assert.equals("ReviewDiffDeleteWord", chunks[1][2])
    dv:destroy()
  end)
end)

describe("DiffView:render pending blank", function()
  vim.cmd.packadd("codediff.nvim")
  local diff = require("app.review.ui.diff")
  local git = require("app.review.diff.git")

  local hunks = {
    {
      old_start = 1,
      old_count = 1,
      new_start = 1,
      new_count = 1,
      lines = {
        { kind = "del", text = "a", old_lnum = 1 },
        { kind = "add", text = "A", new_lnum = 1 },
      },
    },
  }

  -- git.show stub that answers immediately while `hold` is false and parks
  -- the callbacks otherwise, standing in for a slow load.
  local hold = false
  local parked = {}
  local orig
  before_each(function()
    orig = git.show
    hold, parked = false, {}
    git.show = function(_, ref, _, cb)
      local content = ref == "HEAD" and "a" or "A"
      if hold then
        table.insert(parked, function()
          cb(content, nil)
        end)
      else
        cb(content, nil)
      end
    end
  end)
  after_each(function()
    git.show = orig
  end)

  local function lines(dv)
    return vim.api.nvim_buf_get_lines(dv.right.bufnr, 0, -1, false)
  end

  local function past_delay()
    vim.wait(diff.PENDING_BLANK_MS + 100, function()
      return false
    end)
  end

  it("blanks a slow file switch after the delay, then lands over the blank", function()
    local dv = diff.new({ win = vim.api.nvim_get_current_win() })
    dv:render({ path = "a.txt", hunks = hunks }, "/tmp")
    assert.same({ "A" }, lines(dv))

    hold = true
    local blanked = false
    dv:render({ path = "b.txt", hunks = hunks }, "/tmp", nil, nil, function()
      blanked = true
    end)
    assert.same({ "A" }, lines(dv))
    past_delay()
    assert.is_true(blanked)
    assert.same({ "" }, lines(dv))

    for _, f in ipairs(parked) do
      f()
    end
    assert.same({ "A" }, lines(dv))
    dv:destroy()
  end)

  it("blanks during a scan whose every step supersedes the last", function()
    local dv = diff.new({ win = vim.api.nvim_get_current_win() })
    dv:render({ path = "a.txt", hunks = hunks }, "/tmp")
    hold = true
    local labels = {}
    -- Steps closer together than the delay, as the outline's throttled
    -- on_change produces while a key repeats.
    local step = math.floor(diff.PENDING_BLANK_MS / 2)
    for i = 1, 6 do
      local path = "f" .. i .. ".txt"
      dv:render({ path = path, hunks = hunks }, "/tmp", nil, nil, function()
        table.insert(labels, path)
      end)
      vim.wait(step, function()
        return false
      end)
    end
    assert.same({ "" }, lines(dv))
    -- The blank labels the file under the cursor at each step after it.
    assert.equals("f6.txt", labels[#labels])
    dv:destroy()
  end)

  it("leaves a quick file switch alone", function()
    local dv = diff.new({ win = vim.api.nvim_get_current_win() })
    dv:render({ path = "a.txt", hunks = hunks }, "/tmp")
    local blanked = false
    dv:render({ path = "b.txt", hunks = hunks }, "/tmp", nil, nil, function()
      blanked = true
    end)
    past_delay()
    assert.is_false(blanked)
    assert.same({ "A" }, lines(dv))
    dv:destroy()
  end)

  it("keeps the content up while a refresh of the same file loads", function()
    local dv = diff.new({ win = vim.api.nvim_get_current_win() })
    dv:render({ path = "a.txt", hunks = hunks }, "/tmp")
    hold = true
    local blanked = false
    dv:render({ path = "a.txt", hunks = hunks }, "/tmp", nil, nil, function()
      blanked = true
    end)
    past_delay()
    assert.is_false(blanked)
    assert.same({ "A" }, lines(dv))
    dv:destroy()
  end)
end)
