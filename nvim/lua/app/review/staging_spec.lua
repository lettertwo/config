local assert = require("luassert")
local staging = require("app.review.staging")
local parser = require("app.review.diff.parser")

describe("staging queue", function()
  it("runs ops strictly one at a time (FIFO)", function()
    local log = {}
    local release1
    staging._enqueue(function(cb)
      table.insert(log, "op1")
      release1 = cb
    end)
    staging._enqueue(function(cb)
      table.insert(log, "op2")
      cb()
    end)
    -- op2 must not start while op1 is in flight.
    assert.same({ "op1" }, log)
    assert.equals(2, staging._queue_len())
    release1()
    assert.same({ "op1", "op2" }, log)
    vim.wait(200, function()
      return staging._queue_len() == 0
    end, 10)
    assert.equals(0, staging._queue_len())
  end)

  it("schedules on_done after completion", function()
    local done = false
    staging._enqueue(function(cb)
      cb()
    end, function()
      done = true
    end)
    -- on_done goes through vim.schedule; it must not have run synchronously.
    assert.is_false(done)
    vim.wait(200, function()
      return done
    end, 10)
    assert.is_true(done)
  end)

  it("retries once on index.lock contention", function()
    local notified
    local orig = vim.notify
    vim.notify = function(msg, level)
      if level == vim.log.levels.ERROR then
        notified = msg
      end
    end
    local attempts = 0
    local done = false
    staging._enqueue(function(cb)
      attempts = attempts + 1
      if attempts == 1 then
        cb("fatal: Unable to create '/x/.git/index.lock': File exists.")
      else
        cb()
      end
    end, function()
      done = true
    end)
    vim.wait(500, function()
      return done
    end, 10)
    vim.notify = orig
    assert.equals(2, attempts)
    assert.is_true(done)
    assert.is_nil(notified)
    assert.equals(0, staging._queue_len())
  end)

  it("surfaces the error when the index.lock retry fails too", function()
    local notified
    local orig = vim.notify
    vim.notify = function(msg, level)
      if level == vim.log.levels.ERROR then
        notified = msg
      end
    end
    local attempts = 0
    staging._enqueue(function(cb)
      attempts = attempts + 1
      cb("fatal: Unable to create '/x/.git/index.lock': File exists.")
    end)
    vim.wait(500, function()
      return staging._queue_len() == 0
    end, 10)
    vim.notify = orig
    assert.equals(2, attempts)
    assert.is_truthy(notified and notified:match("index%.lock"))
  end)

  it("notifies errors and keeps the queue moving", function()
    local notified
    local orig = vim.notify
    vim.notify = function(msg, level)
      if level == vim.log.levels.ERROR then
        notified = msg
      end
    end
    local ran2 = false
    staging._enqueue(function(cb)
      cb("boom")
    end)
    staging._enqueue(function(cb)
      ran2 = true
      cb()
    end)
    vim.wait(200, function()
      return staging._queue_len() == 0
    end, 10)
    vim.notify = orig
    assert.is_truthy(notified and notified:match("boom"))
    assert.is_true(ran2)
  end)
end)

describe("staging.toggle_tree (real repo)", function()
  local function make_repo()
    local cwd = vim.fn.tempname()
    vim.fn.mkdir(cwd .. "/sub", "p")
    vim.fn.writefile({ "1" }, cwd .. "/sub/a.lua")
    local function run(...)
      local r = vim.system({ "git", ... }, { cwd = cwd, text = true }):wait()
      assert.equals(0, r.code, r.stderr)
      return r.stdout or ""
    end
    run("init", "-q")
    run("config", "user.email", "t@t")
    run("config", "user.name", "t")
    run("add", ".")
    run("commit", "-qm", "init")
    return cwd, run
  end

  it("stages an unstaged subtree, then unstages it on repeat (live-state toggle)", function()
    local cwd, run = make_repo()
    vim.fn.writefile({ "1", "2" }, cwd .. "/sub/a.lua")

    local done1 = false
    staging.toggle_tree(cwd, "sub", function()
      done1 = true
    end)
    vim.wait(4000, function()
      return done1
    end, 10)
    assert.is_truthy(run("diff", "--cached"):match("%+2"))

    local done2 = false
    staging.toggle_tree(cwd, "sub", function()
      done2 = true
    end)
    vim.wait(4000, function()
      return done2
    end, 10)
    assert.equals("", run("diff", "--cached"))
  end)
end)

describe("staging file ops (real repo)", function()
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

  it("deletes an untracked file entirely, leaving no trace in the worktree or status", function()
    local cwd, run = make_repo()
    vim.fn.writefile({ "new" }, cwd .. "/new.lua")

    local done = false
    staging.delete_untracked(cwd, "new.lua", function()
      done = true
    end)
    vim.wait(4000, function()
      return done
    end, 10)
    assert.equals(0, vim.fn.filereadable(cwd .. "/new.lua"))
    assert.equals("", run("ls-files", "--others", "--exclude-standard"))
  end)

  it("discarding a partially staged file reverts the worktree to the INDEX, not HEAD", function()
    local cwd, run = make_repo()
    vim.fn.writefile({ "committed" }, cwd .. "/f.lua")
    run("add", ".")
    run("commit", "-qm", "init")
    vim.fn.writefile({ "staged" }, cwd .. "/f.lua")
    run("add", ".")
    vim.fn.writefile({ "workdir" }, cwd .. "/f.lua")

    local done = false
    staging.discard_file(cwd, "f.lua", function()
      done = true
    end)
    vim.wait(4000, function()
      return done
    end, 10)
    local fh = assert(io.open(cwd .. "/f.lua", "rb"))
    local content = fh:read("*a")
    fh:close()
    assert.equals("staged\n", content)
    assert.equals("staged\n", run("show", ":f.lua"))
  end)

  it("stages an untracked broken symlink by its link text, at mode 120000", function()
    local cwd, run = make_repo()
    local ok = vim.uv.fs_symlink("nonexistent-target", cwd .. "/link.lua")
    assert.is_true(ok ~= nil)

    local done = false
    staging.stage_file(cwd, "link.lua", function()
      done = true
    end)
    vim.wait(4000, function()
      return done
    end, 10)
    local staged = run("ls-files", "--stage", "link.lua")
    assert.truthy(staged:match("^120000"), staged)
    assert.equals("nonexistent-target", run("show", ":link.lua"))
  end)

  it("TRIPWIRE: a properly-headed binary-file stage routes here, not through a synthesized hunk patch", function()
    -- Binary files carry no hunks (parser.parse sets status "B" and never
    -- opens a hunk for a "Binary files ... differ" body), so the only path
    -- that can stage a binary change at all is the file-level primitive this
    -- exercises directly. This pins the destination's byte correctness; the
    -- routing decision itself (docket.lua's hunkwise guard sending status
    -- "B" here instead of a hunk op) needs a rendered Docket to drive and is
    -- covered at that level in docket_spec.lua.
    local cwd, run = make_repo()
    local function write_bin(content)
      local fh = assert(io.open(cwd .. "/blob.bin", "wb"))
      fh:write(content)
      fh:close()
    end
    write_bin("\0\1\2old")
    run("add", ".")
    run("commit", "-qm", "init")
    write_bin("\0\1\2new")

    local done = false
    staging.stage_file(cwd, "blob.bin", function()
      done = true
    end)
    vim.wait(4000, function()
      return done
    end, 10)
    -- text=false: the blob carries a NUL byte, which vim.system's text
    -- decoding would otherwise mangle.
    local shown = vim.system({ "git", "show", ":blob.bin" }, { cwd = cwd }):wait()
    assert.equals(0, shown.code, shown.stderr)
    assert.equals("\0\1\2new", shown.stdout)
  end)

  it("staging storm: stage/unstage/discard three files through the queue in one go", function()
    local cwd, run = make_repo()
    for _, name in ipairs({ "fileA", "fileB", "fileC" }) do
      vim.fn.writefile({ "x1", "x2", "x3", "" }, cwd .. "/" .. name)
    end
    run("add", ".")
    run("commit", "-qm", "init")
    for _, name in ipairs({ "fileA", "fileB", "fileC" }) do
      vim.fn.writefile({ "x1", "CHANGED", "x3", "" }, cwd .. "/" .. name)
    end
    -- fileB's change is pre-staged; fileA and fileC stay unstaged.
    run("add", "fileB")

    local function parse_unstaged(name)
      local r = vim.system(
        { "git", "diff", "--no-color", "--unified=3", "--", name },
        { cwd = cwd, text = true }
      ):wait()
      return parser.parse(r.stdout)[1]
    end
    local function parse_staged(name)
      local r = vim.system(
        { "git", "diff", "--no-color", "--cached", "HEAD", "--", name },
        { cwd = cwd, text = true }
      ):wait()
      return parser.parse(r.stdout)[1]
    end

    local file_a = parse_unstaged("fileA")
    local file_b = parse_staged("fileB")
    local file_c = parse_unstaged("fileC")

    staging.stage_hunk(cwd, file_a, file_a.hunks[1])
    staging.unstage_hunk(cwd, file_b, file_b.hunks[1])
    staging.discard_hunk(cwd, file_c, file_c.hunks[1])
    vim.wait(4000, function()
      return staging._queue_len() == 0
    end, 10)

    -- fileA: staged the whole (only) hunk — index differs from HEAD, worktree
    -- has nothing left unstaged.
    assert.is_truthy(run("diff", "--cached", "--name-only"):match("fileA"))
    assert.equals("", run("diff", "--name-only", "--", "fileA"))
    -- fileB: unstaged back to HEAD, but the worktree edit is untouched.
    assert.equals("", run("diff", "--cached", "--name-only", "--", "fileB"))
    assert.is_truthy(run("diff", "--name-only"):match("fileB"))
    -- fileC: discarded back to the index (== HEAD here); nothing pending.
    assert.equals("", run("status", "--porcelain", "--", "fileC"))
  end)

  it("TRIPWIRE: a creation patch without a mode header is REJECTED by git apply --cached", function()
    -- Naive shape a one-sided creation patch would take if it copied
    -- hunk_to_patch's plain a/-b/ headers verbatim: no `new file mode` line,
    -- a mode-suffixed `index` line as if the file already existed. git's
    -- is-new flag comes only from the mode line, so this parses as a
    -- MODIFICATION of an absent index entry and fails. This is exactly why
    -- untracked files stage through `git add` (staging.stage_file) rather
    -- than a synthesized patch.
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
    vim.fn.writefile({ "hello" }, cwd .. "/new.txt")

    local raw = table.concat({
      "diff --git a/new.txt b/new.txt",
      "index 0000000..0000000 100644",
      "--- /dev/null",
      "+++ b/new.txt",
      "@@ -0,0 +1,1 @@",
      "+hello",
    }, "\n") .. "\n"
    local r = vim.system({ "git", "apply", "--cached", "-" }, { cwd = cwd, text = true, stdin = raw }):wait()
    assert.is_true(r.code ~= 0, "expected git apply --cached to reject the mode-line-less creation patch")
  end)
end)
