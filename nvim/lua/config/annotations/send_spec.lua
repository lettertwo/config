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
