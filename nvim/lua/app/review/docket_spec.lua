local assert = require("luassert")
local docket = require("app.review.docket")
local staging = require("app.review.staging")
local parser = require("app.review.diff.parser")

describe("docket._gate", function()
  local function file(opts)
    opts = opts or {}
    return {
      path = "f.lua",
      head_ref = opts.head_ref or "WORKTREE",
      unstaged = opts.unstaged and {} or nil,
      staged_change = opts.staged and {} or nil,
    }
  end

  it("collapses to whole/plain when the source can't stage, naming why", function()
    local stageable, view, why = docket._gate(false, file({ unstaged = true, staged = true }), "split")
    assert.is_false(stageable)
    assert.equals("whole", view)
    assert.equals("unstageable", why)
  end)

  it("collapses non-worktree files (stack commits) to whole/plain as committed", function()
    local stageable, view, why = docket._gate(true, file({ head_ref = "abc123", unstaged = true }), "split")
    assert.is_false(stageable)
    assert.equals("whole", view)
    assert.equals("committed", why)
  end)

  it("collapses a nil file to whole/plain as committed", function()
    local stageable, view, why = docket._gate(true, nil, "split")
    assert.is_false(stageable)
    assert.equals("whole", view)
    assert.equals("committed", why)
  end)

  it("collapses files without sub-diffs to whole/plain, naming why", function()
    local stageable, view, why = docket._gate(true, file(), "split")
    assert.is_false(stageable)
    assert.equals("whole", view)
    assert.equals("unstageable", why)
  end)

  it("honors the whole view request on a stageable file, attributed", function()
    local stageable, view, why = docket._gate(true, file({ unstaged = true, staged = true }), "whole")
    assert.is_true(stageable)
    assert.equals("whole", view)
    assert.is_nil(why)
  end)

  it("keeps the split only when both sub-diffs exist", function()
    local stageable, view, why = docket._gate(true, file({ unstaged = true, staged = true }), "split")
    assert.is_true(stageable)
    assert.equals("split", view)
    assert.is_nil(why)
  end)

  it("collapses the split to the unstaged side alone", function()
    local stageable, view, why = docket._gate(true, file({ unstaged = true }), "split")
    assert.is_true(stageable)
    assert.equals("unstaged", view)
    assert.is_nil(why)
  end)

  it("collapses the split to the staged side alone", function()
    local stageable, view, why = docket._gate(true, file({ staged = true }), "split")
    assert.is_true(stageable)
    assert.equals("staged", view)
    assert.is_nil(why)
  end)
end)

describe("docket: cursor-scoped staging ops (fake pane)", function()
  -- A minimal DiffView test double: only the methods the cursor-scoped
  -- staging paths call. A real DiffView needs rendered windows/buffers,
  -- which the routing decisions and refusal gates under test don't touch.
  local function fake_dv(file, hunk)
    return {
      right = { bufnr = vim.api.nvim_get_current_buf() },
      _rendered_file = file,
      pane_for_win = function()
        return true
      end,
      hunk_at = function()
        return hunk
      end,
      -- Called as `dv:row_to_source(win, row0)`: the leading `self` from the
      -- colon call is a real parameter here, not the ignored one.
      row_to_source = function(_, _, row0)
        return { side = "RIGHT", lnum = row0 + 1 }
      end,
      hunks_in_range = function()
        return hunk and { hunk } or {}
      end,
      destroy = function() end,
    }
  end

  local function make_repo()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd, "p")
    local function run(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
      return r.stdout or ""
    end
    run("init", "-q")
    run("config", "user.email", "t@t")
    run("config", "user.name", "t")
    return cwd, run
  end

  -- One row rendered as the unstaged pane, with `file` under the cursor.
  -- `refresh` is stubbed: the real one needs a full source and outline the
  -- fake docket doesn't have, and these ops decide their route synchronously
  -- before any refresh would fire.
  local function fake_docket(cwd, file, hunk)
    local dv = fake_dv(file, hunk)
    local dk = docket.new({
      kind = "test",
      cwd = cwd,
      title = "test",
      win = vim.api.nvim_get_current_win(),
      dv = dv,
      dv2 = fake_dv(file, hunk),
      source = {
        can_stage = function()
          return true
        end,
      },
    })
    dk.files = { file }
    dk.idx = 1
    dk._rendered = { { dv = dv, file = file, role = "unstaged" } }
    dk.refresh = function() end
    return dk
  end

  it("routes a binary file's hunk-stage to the file-level primitive, staging the modified bytes", function()
    local cwd = make_repo()
    local function write_bin(content)
      local fh = assert(io.open(cwd .. "/blob.bin", "wb"))
      fh:write(content)
      fh:close()
    end
    write_bin("\0old")
    vim.system({ "git", "add", "." }, { cwd = cwd }):wait()
    vim.system({ "git", "commit", "-qm", "init" }, { cwd = cwd }):wait()
    write_bin("\0new")

    -- No hunk exists for a binary file (parser.parse never opens one for a
    -- "Binary files ... differ" body); `hunk_at` still returns a truthy
    -- dummy here since only the routing past it is under test.
    local file = { path = "blob.bin", status = "B", head_ref = "WORKTREE", unstaged = {} }
    local dk = fake_docket(cwd, file, {})
    dk:stage_current()
    vim.wait(4000, function()
      return staging._queue_len() == 0
    end, 10)
    local shown = vim.system({ "git", "show", ":blob.bin" }, { cwd = cwd }):wait()
    assert.equals(0, shown.code, shown.stderr)
    assert.equals("\0new", shown.stdout)
    dk:destroy()
  end)

  it("TRIPWIRE routing: staging a deleted file removes the index entry, not an empty blob", function()
    -- A naive whole-hunk patch for a deletion (a/-b/ headers kept as if the
    -- file still existed) is ACCEPTED by `git apply --cached` and stages an
    -- EMPTY BLOB instead of removing the path — the routing below is what
    -- keeps that shape from ever being built.
    local cwd, run = make_repo()
    vim.fn.writefile({ "content" }, cwd .. "/gone.lua")
    run("add", ".")
    run("commit", "-qm", "init")
    os.remove(cwd .. "/gone.lua")

    local file = { path = "gone.lua", status = "D", head_ref = "WORKTREE", unstaged = {} }
    local dk = fake_docket(cwd, file, {})
    dk:stage_current()
    vim.wait(4000, function()
      return staging._queue_len() == 0
    end, 10)
    assert.equals("", run("ls-files", "--cached", "gone.lua"))
    assert.truthy(run("status", "--porcelain"):match("^D "))
    dk:destroy()
  end)

  it("refuses a line selection on a deleted file without running git", function()
    local cwd = make_repo()
    local file = { path = "gone.lua", status = "D", head_ref = "WORKTREE", unstaged = {} }
    local dk = fake_docket(cwd, file, nil)
    local notified
    local orig = vim.notify
    vim.notify = function(msg)
      notified = msg
    end
    local before = staging._queue_len()
    dk:stage_selection(1, 1)
    vim.notify = orig
    assert.equals(before, staging._queue_len())
    assert.truthy(notified and notified:match("line staging needs a modified or new file"))
    dk:destroy()
  end)

  it("refuses an empty (context-only) line selection without running git", function()
    local cwd = make_repo()
    local hunk = parser.parse(table.concat({
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
    }, "\n") .. "\n")[1].hunks[1]
    local file = { path = "f.lua", status = "M", head_ref = "WORKTREE", unstaged = {}, hunks = { hunk } }
    local dk = fake_docket(cwd, file, hunk)
    local notified
    local orig = vim.notify
    vim.notify = function(msg)
      notified = msg
    end
    local before = staging._queue_len()
    -- Row 1 maps, via the fake pane's row_to_source, to RIGHT lnum 1: ctx1,
    -- a context row untouched by either side of the change.
    dk:stage_selection(1, 1)
    vim.notify = orig
    assert.equals(before, staging._queue_len())
    assert.truthy(notified and notified:match("no changed lines in selection"))
    dk:destroy()
  end)

  -- An untracked file's whole content renders as one hunk of add-only lines
  -- (parser.hunk_to_patch_lines's own /dev/null headers, exercised end-to-end
  -- in staging_spec.lua); this pins the routing decision that reaches it.
  local function untracked_multi_hunk()
    return parser.parse(table.concat({
      "diff --git a/multi.txt b/multi.txt",
      "new file mode 100644",
      "--- /dev/null",
      "+++ b/multi.txt",
      "@@ -0,0 +1,4 @@",
      "+one",
      "+two",
      "+three",
      "+four",
    }, "\n") .. "\n")[1].hunks[1]
  end

  it("routes a line selection on an untracked file to a real stage instead of refusing", function()
    local cwd = make_repo()
    vim.fn.writefile({ "one", "two", "three", "four" }, cwd .. "/multi.txt")
    local hunk = untracked_multi_hunk()
    local file = { path = "multi.txt", status = "U", head_ref = "WORKTREE", unstaged = {}, hunks = { hunk } }
    local dk = fake_docket(cwd, file, hunk)
    -- Row 2 maps to RIGHT lnum 2: "two" alone.
    dk:stage_selection(2, 2)
    vim.wait(4000, function()
      return staging._queue_len() == 0
    end, 10)
    local shown = vim.system({ "git", "show", ":multi.txt" }, { cwd = cwd, text = true }):wait()
    assert.equals(0, shown.code, shown.stderr)
    assert.equals("two\n", shown.stdout)
    dk:destroy()
  end)

  it("routes a full-selection discard on an untracked file to file removal, not an empty patch", function()
    local cwd = make_repo()
    vim.fn.writefile({ "one", "two", "three", "four" }, cwd .. "/multi.txt")
    local hunk = untracked_multi_hunk()
    local file = { path = "multi.txt", status = "U", head_ref = "WORKTREE", unstaged = {}, hunks = { hunk } }
    local dk = fake_docket(cwd, file, hunk)
    dk._confirm = function()
      return true
    end
    -- Rows 1-4 cover every line of the file.
    dk:discard_selection(1, 4)
    vim.wait(4000, function()
      return staging._queue_len() == 0
    end, 10)
    assert.equals(0, vim.fn.filereadable(cwd .. "/multi.txt"), "a full-selection discard must remove the file, not leave it empty")
    dk:destroy()
  end)
end)

describe("docket: changeset nav past a fileless changeset", function()
  -- Bare enough for next_changeset/prev_changeset and set_changesets, which
  -- is all this exercises; render never runs.
  local function fake_dv()
    return { right = { bufnr = vim.api.nvim_get_current_buf() }, destroy = function() end }
  end

  local function fake_docket()
    local dk = docket.new({
      kind = "test",
      cwd = "/tmp",
      title = "test",
      win = vim.api.nvim_get_current_win(),
      dv = fake_dv(),
      dv2 = fake_dv(),
      source = {
        can_stage = function()
          return false
        end,
      },
    })
    dk.show_file = function()
      return true
    end
    return dk
  end

  -- A Pending or Failed changeset has no files (source/changesets.lua never
  -- fills `files` for either), so it never occupies a slot in `self.files` —
  -- next_changeset/prev_changeset walk that list, so they land on the next
  -- real file on either side without ever seeing the empty one.
  local function changesets()
    return {
      { id = "a", title = "a", status = "ready", files = { { path = "a.lua", changeset_id = "a" } } },
      { id = "b", title = "b", status = "pending", files = {} },
      { id = "c", title = "c", status = "failed", error = "boom", files = {} },
      { id = "d", title = "d", status = "ready", files = { { path = "d.lua", changeset_id = "d" } } },
    }
  end

  it("next_changeset skips a Pending and a Failed changeset with no files", function()
    local dk = fake_docket()
    dk:set_changesets(changesets())
    dk.idx = 1
    dk:next_changeset()
    assert.equals("d.lua", dk.files[dk.idx].path)
    dk:destroy()
  end)

  it("prev_changeset skips back over the same fileless changesets", function()
    local dk = fake_docket()
    dk:set_changesets(changesets())
    dk.idx = 2 -- d.lua, the second (and last) entry in self.files
    dk:prev_changeset()
    assert.equals("a.lua", dk.files[dk.idx].path)
    dk:destroy()
  end)
end)
