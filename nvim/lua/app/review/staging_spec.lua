local assert = require("luassert")
local staging = require("app.review.staging")

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
