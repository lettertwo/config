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
      return e.opts.sign_hl_group == "ReviewSignChange"
    end))
    assert.equals(1, count(ann.exts_r, function(e)
      return e.opts.sign_hl_group == "ReviewSignChange"
    end))
    assert.equals(2, count(ann.exts_r, function(e)
      return e.opts.sign_hl_group == "ReviewSignAdd"
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
    -- Combined file with one unstaged add (worktree lnum 5) and one staged
    -- del (HEAD lnum 3).
    local file = {
      path = "f.lua",
      unstaged = { hunks = { { lines = { { kind = "add", text = "u", new_lnum = 5 } } } } },
      staged_change = { hunks = { { lines = { { kind = "del", text = "s", old_lnum = 3 } } } } },
    }
    local pick_add, pick_del = diff._group_pickers("attributed", file)
    -- Unstaged add keeps plain colors; any other combined add is staged.
    assert.equals("ReviewDiffAdd", pick_add(5).add)
    assert.equals("ReviewDiffStagedAdd", pick_add(6).add)
    -- Staged del gets staged colors; any other combined del is unstaged.
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
end)
