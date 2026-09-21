-- Sends pending annotations to the Claude Code session running in another
-- kitty window: writes the feedback file, finds the window, and types
-- `/annotations` into it. The skill on the Claude side finds the file itself
-- (newest under `claude-annotations/` in its own repo), so no path travels
-- over the wire.

local Store = require("config.annotations.store")
local Export = require("config.annotations.export")

local Send = {}

local kitty_socket_override = nil

-- Applies configuration from `config/annotations/init.lua`: which kitty
-- socket to dial. Falls back to `$KITTY_LISTEN_ON`, then kitty's default.
---@param opts { kitty_socket?: string }
function Send.configure(opts)
  opts = opts or {}
  kitty_socket_override = opts.kitty_socket
end

local function kitty_socket()
  return kitty_socket_override or vim.env.KITTY_LISTEN_ON or "unix:/tmp/kitty.sock"
end

local function kitty(args)
  local cmd = vim.list_extend({ "kitty", "@", "--to", kitty_socket() }, args)
  return vim.system(cmd, { text = true }):wait()
end

-- A tag or a process cwd matches when it's the toplevel itself or a path
-- under it, so a Claude started in a subdirectory of the worktree still
-- matches: kitty-tag.sh tags the toplevel it resolves at hook time, but an
-- older-tagged window or the process-cwd fallback can still carry a
-- subdirectory.
---@param candidate string
---@param toplevel string
---@return boolean
local function under_toplevel(candidate, toplevel)
  local normalized = vim.fs.normalize(candidate)
  return normalized == toplevel or normalized:sub(1, #toplevel + 1) == toplevel .. "/"
end

-- Pure over the `kitty @ ls` JSON: windows tagged by claude/kitty-tag.sh
-- with claude_cwd under toplevel win over windows whose foreground process
-- is a `claude` invocation cwd'd there.
---@param os_windows table[] decoded `kitty @ ls` output
---@param toplevel string
---@return table[] windows
function Send._match_windows(os_windows, toplevel)
  local tagged, by_process = {}, {}
  for _, os_window in ipairs(os_windows) do
    for _, tab in ipairs(os_window.tabs or {}) do
      for _, win in ipairs(tab.windows or {}) do
        local user_vars = win.user_vars or {}
        if user_vars.claude_cwd and under_toplevel(user_vars.claude_cwd, toplevel) then
          table.insert(tagged, win)
        else
          for _, proc in ipairs(win.foreground_processes or {}) do
            local cmdline = proc.cmdline or {}
            if proc.cwd and under_toplevel(proc.cwd, toplevel) and cmdline[1] and cmdline[1]:match("claude$") then
              table.insert(by_process, win)
              break
            end
          end
        end
      end
    end
  end

  return #tagged > 0 and tagged or by_process
end

-- Windows tagged by claude/kitty-tag.sh with claude_cwd under toplevel, else
-- windows whose foreground process is a `claude` invocation cwd'd there.
---@param toplevel string
---@return table[] windows, string? err
local function find_claude_windows(toplevel)
  local result = kitty({ "ls" })
  if result.code ~= 0 then
    return {}, "kitty @ ls failed: " .. (result.stderr or "")
  end
  local ok, os_windows = pcall(vim.json.decode, result.stdout)
  if not ok then
    return {}, "kitty @ ls returned invalid JSON"
  end

  return Send._match_windows(os_windows, toplevel), nil
end

-- Exports pending annotations, finds the Claude window for this repo, and
-- types `/annotations` into it. Leaves the feedback file and does not mark
-- anything sent if no window is found, or if more than one is ambiguous and
-- the user cancels the picker.
function Send.send()
  local pending = Store.pending()
  if #pending == 0 then
    vim.notify("No pending annotations to send", vim.log.levels.INFO, { title = "Annotations" })
    return
  end

  local cwd = vim.uv.cwd()
  local toplevel = Store.toplevel(cwd)
  local git_dir = Store.git_dir(cwd)
  if not toplevel or not git_dir then
    vim.notify("Not inside a git worktree", vim.log.levels.ERROR, { title = "Annotations" })
    return
  end

  local batch = os.date("%Y%m%d-%H%M%S")
  local feedback_dir = vim.fs.joinpath(git_dir, "claude-annotations")
  vim.fn.mkdir(feedback_dir, "p")
  local feedback_path = vim.fs.joinpath(feedback_dir, "feedback-" .. batch .. ".md")
  vim.fn.writefile(vim.split(Export.render(pending, toplevel, batch), "\n"), feedback_path)

  local windows, err = find_claude_windows(toplevel)
  if err then
    vim.notify(err, vim.log.levels.ERROR, { title = "Annotations" })
    return
  end
  if #windows == 0 then
    vim.notify(
      "No Claude window found for " .. toplevel .. "; feedback left at " .. feedback_path,
      vim.log.levels.WARN,
      { title = "Annotations" }
    )
    return
  end

  local function send_to(win)
    local send_result = kitty({
      "send-text",
      "--match",
      "id:" .. win.id,
      "/annotations\r",
    })
    if send_result.code ~= 0 then
      vim.notify("kitty send-text failed: " .. (send_result.stderr or ""), vim.log.levels.ERROR, { title = "Annotations" })
      return
    end
    local ids = {}
    for _, rec in ipairs(pending) do
      table.insert(ids, rec.id)
    end
    Store.mark_sent(ids, batch)
  end

  if #windows == 1 then
    send_to(windows[1])
    return
  end

  vim.ui.select(windows, {
    prompt = "Multiple Claude windows found, pick one:",
    format_item = function(win)
      return string.format("id %d, tab %s", win.id, win.title or "")
    end,
  }, function(choice)
    if choice then
      send_to(choice)
    end
  end)
end

return Send
