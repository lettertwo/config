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

  it("collapses to plain combined when the source can't stage", function()
    local stageable, zoom = docket._gate(false, file({ unstaged = true, staged = true }), "split")
    assert.is_false(stageable)
    assert.equals("combined", zoom)
  end)

  it("collapses non-worktree files (stack commits) to plain combined", function()
    local stageable, zoom = docket._gate(true, file({ head_ref = "abc123", unstaged = true }), "split")
    assert.is_false(stageable)
    assert.equals("combined", zoom)
  end)

  it("collapses files without sub-diffs to plain combined", function()
    local stageable, zoom = docket._gate(true, file(), "split")
    assert.is_false(stageable)
    assert.equals("combined", zoom)
  end)

  it("keeps the split only when both sub-diffs exist", function()
    local stageable, zoom = docket._gate(true, file({ unstaged = true, staged = true }), "split")
    assert.is_true(stageable)
    assert.equals("split", zoom)
  end)

  it("collapses the split to the side that exists", function()
    local _, zoom = docket._gate(true, file({ unstaged = true }), "split")
    assert.equals("unstaged", zoom)
    local _, zoom2 = docket._gate(true, file({ staged = true }), "split")
    assert.equals("staged", zoom2)
  end)

  it("falls back to combined when the requested single pane is absent", function()
    local _, zoom = docket._gate(true, file({ staged = true }), "unstaged")
    assert.equals("combined", zoom)
    local _, zoom2 = docket._gate(true, file({ unstaged = true }), "staged")
    assert.equals("combined", zoom2)
  end)

  it("honors an available single-pane request and combined", function()
    local stageable, zoom = docket._gate(true, file({ unstaged = true, staged = true }), "staged")
    assert.is_true(stageable)
    assert.equals("staged", zoom)
    local _, zoom2 = docket._gate(true, file({ unstaged = true, staged = true }), "combined")
    assert.equals("combined", zoom2)
  end)

  it("handles a nil file (empty docket)", function()
    local stageable, zoom = docket._gate(true, nil, "split")
    assert.is_false(stageable)
    assert.equals("combined", zoom)
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
      row_to_source = function(_, row0)
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

  it("refuses a line selection on a non-hunkwise file without running git", function()
    local cwd = make_repo()
    local file = { path = "new.lua", status = "U", head_ref = "WORKTREE", unstaged = {} }
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
    assert.truthy(notified and notified:match("line staging needs a modified file"))
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
end)
