-- Launches a new Kitty OS window running Claude Code in plan mode,
-- seeded with context about the nearest task marker (TODO/FIXME/HACK/XXX).
--
-- `:ClaudeTask` / `<leader>at` — nearest task in the current buffer
-- `<C-t>` in the todo_comments snacks picker — selected task

---@param file string absolute path to the file containing the task
---@param lnum integer 1-indexed line number
---@param task_text string the task comment text (may be multi-line)
local function launch_claude_task(file, lnum, task_text)
  if not vim.env.KITTY_WINDOW_ID then
    vim.notify("ClaudeTask: not running inside Kitty", vim.log.levels.WARN)
    return
  end

  local root = LazyVim.root()
  local rel = vim.fn.fnamemodify(file, ":.")

  local prompt = string.format(
    "In the file `%s` at line %d, there is the following task:\n\n%s\n\nThe project root is %s. Analyze this task and create a detailed implementation plan.",
    rel,
    lnum,
    task_text,
    root
  )

  vim.system({
    "kitty",
    "@",
    "launch",
    "--type=window",
    "--cwd",
    root,
    "claude",
    "--verbose",
    "--permission-mode",
    "plan",
    prompt,
  })
end

-- Task marker patterns (Lua patterns, 0-indexed capture positions).
-- Returns keyword and start position if matched, nil otherwise.
---@param line string
---@return string?, integer?
local function match_task(line)
  for _, kw in ipairs({ "TODO", "FIXME", "HACK", "XXX" }) do
    local s = line:find("%f[%w]" .. kw .. "%f[%W]")
    if s then
      return kw, s
    end
  end
  -- Rust-style macros: todo!( unimplemented!(
  for _, pat in ipairs({ "todo%s*!%s*%(", "unimplemented%s*!%s*%(" }) do
    local s = line:find(pat)
    if s then
      return pat:match("%a+"), s
    end
  end
end

-- Detects the comment prefix of a line (e.g. "//", "#", "--", "* ").
---@param line string
---@return string?
local function comment_prefix(line)
  return line:match("^%s*(%-%-%[?%[?)") -- Lua --[[ or --
    or line:match("^%s*(//+)") -- C-style
    or line:match("^%s*(#+)") -- Shell/Python
    or line:match("^%s*(%*+)") -- Block comment continuation
end

-- Extracts the task text starting from `start_lnum` (1-indexed),
-- following continuation lines that share the same comment prefix.
---@param lines string[]
---@param start_lnum integer 1-indexed
---@return string
local function extract_task_text(lines, start_lnum)
  local parts = {}
  local marker_line = lines[start_lnum]
  local prefix = comment_prefix(marker_line)

  -- Strip the comment prefix + leading whitespace from a line.
  local function strip(line)
    if prefix then
      local s = line:match("^%s*" .. vim.pesc(prefix) .. "%s?(.*)")
      if s then
        return s
      end
    end
    return line:match("^%s*(.*)")
  end

  parts[#parts + 1] = strip(marker_line)

  if prefix then
    for i = start_lnum + 1, #lines do
      local l = lines[i]
      if l:match("^%s*" .. vim.pesc(prefix)) then
        parts[#parts + 1] = strip(l)
      else
        break
      end
    end
  end

  return table.concat(parts, "\n")
end

-- Finds the task marker nearest to the cursor in the current buffer.
---@return { lnum: integer, keyword: string, text: string }?
local function find_nearest_task()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local best = nil
  for i, line in ipairs(lines) do
    local kw = match_task(line)
    if kw then
      local dist = math.abs(i - cursor_row)
      -- Prefer above on ties (same distance before/after cursor)
      local better = best == nil or dist < best.dist or (dist == best.dist and i < cursor_row)
      if better then
        best = { lnum = i, keyword = kw, dist = dist, text = extract_task_text(lines, i) }
      end
    end
  end

  if best then
    return { lnum = best.lnum, keyword = best.keyword, text = best.text }
  end
end

-- `:ClaudeTask` implementation — nearest task in the current buffer.
local function launch_nearest()
  if vim.bo.buftype ~= "" then
    vim.notify("ClaudeTask: not a normal buffer", vim.log.levels.WARN)
    return
  end

  local task = find_nearest_task()
  if not task then
    vim.notify("ClaudeTask: no task markers found in buffer", vim.log.levels.WARN)
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  launch_claude_task(file, task.lnum, task.text)
end

-- Snacks picker action — launches Claude for the focused picker item.
---@type table<string, snacks.picker.Action.fn>
local actions = {}
function actions.claude_task(picker, item)
  picker:close()
  if item then
    launch_claude_task(item.file, item.pos and item.pos[1] or 1, item.line or item.text or "")
  end
end

return {
  {
    "folke/todo-comments.nvim",
    keys = {
      { "<leader>at", launch_nearest, desc = "Plan Task with Claude" },
    },
    init = function()
      vim.api.nvim_create_user_command("ClaudeTask", launch_nearest, {
        desc = "Launch Claude in new terminal window for nearest task",
      })
    end,
  },
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        actions = actions,
        sources = {
          todo_comments = {
            win = {
              input = {
                keys = {
                  claude_task = { "<C-t>", "claude_task", desc = "Claude Task (Kitty)", mode = { "n", "i" } },
                },
              },
            },
          },
        },
      },
    },
  },
}
