local assert = require("luassert")
local Send = require("config.annotations.send")

describe("Config.Annotations.Send._match_windows", function()
  local toplevel = "/repo"

  it("matches a window tagged with the toplevel", function()
    local os_windows = {
      { tabs = { { windows = { { id = 1, user_vars = { claude_cwd = "/repo" } } } } } },
    }
    local matched = Send._match_windows(os_windows, toplevel)
    assert.equals(1, #matched)
    assert.equals(1, matched[1].id)
  end)

  it("matches a process cwd'd into a subdirectory of the toplevel", function()
    local os_windows = {
      {
        tabs = {
          {
            windows = {
              {
                id = 2,
                foreground_processes = { { cwd = "/repo/nvim/lua", cmdline = { "/usr/bin/claude" } } },
              },
            },
          },
        },
      },
    }
    local matched = Send._match_windows(os_windows, toplevel)
    assert.equals(1, #matched)
    assert.equals(2, matched[1].id)
  end)

  it("prefers tagged windows over process matches", function()
    local os_windows = {
      {
        tabs = {
          {
            windows = {
              { id = 1, user_vars = { claude_cwd = "/repo" } },
              {
                id = 2,
                foreground_processes = { { cwd = "/repo", cmdline = { "/usr/bin/claude" } } },
              },
            },
          },
        },
      },
    }
    local matched = Send._match_windows(os_windows, toplevel)
    assert.equals(1, #matched)
    assert.equals(1, matched[1].id)
  end)

  it("returns an empty list without erroring when tabs/windows/user_vars are missing", function()
    local os_windows = {
      {},
      { tabs = { {} } },
      { tabs = { { windows = { {} } } } },
    }
    local matched = Send._match_windows(os_windows, toplevel)
    assert.equals(0, #matched)
  end)
end)

describe("Config.Annotations.Send.send", function()
  local Store = require("config.annotations.store")
  local dir, prev_cwd, real_system, real_executable, kitty_calls, send_text_code

  before_each(function()
    prev_cwd = vim.uv.cwd()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
    dir = vim.uv.fs_realpath(dir)
    vim.uv.chdir(dir)
    Store._reset_cache()
    Store.add({ id = "1", file = "f.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })

    kitty_calls = {}
    send_text_code = 0
    real_system = vim.system
    real_executable = vim.fn.executable
    vim.fn.executable = function(name)
      if name == "kitty" then
        return 1
      end
      return real_executable(name)
    end
    vim.system = function(cmd, opts)
      if cmd[1] ~= "kitty" then
        return real_system(cmd, opts)
      end
      table.insert(kitty_calls, cmd)
      local verb = cmd[5]
      local result = { code = 0, stdout = "", stderr = "" }
      if verb == "ls" then
        result.stdout = vim.json.encode({ { tabs = { { windows = { { id = 7, user_vars = { claude_cwd = dir } } } } } } })
      else
        result.code = send_text_code
      end
      return {
        wait = function()
          return result
        end,
      }
    end
  end)

  after_each(function()
    vim.system = real_system
    vim.fn.executable = real_executable
    vim.uv.chdir(prev_cwd)
    vim.fn.delete(dir, "rf")
  end)

  local function sent_text()
    for _, cmd in ipairs(kitty_calls) do
      if cmd[5] == "send-text" then
        return cmd[#cmd]
      end
    end
  end

  it("types the feedback path after /annotations and marks the records sent", function()
    Send.send()

    local text = sent_text()
    assert.is_not_nil(text)
    local path = text:match("^/annotations (.+)\r$")
    assert.is_not_nil(path)
    assert.equals(1, vim.fn.filereadable(path))
    assert.equals(0, #Store.pending())
  end)

  it("leaves records unsent when send-text fails", function()
    send_text_code = 1
    Send.send()

    assert.is_not_nil(sent_text())
    assert.equals(1, #Store.pending())
  end)
end)
