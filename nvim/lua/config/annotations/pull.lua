-- Headless export for the `/annotations` skill when nvim hasn't pushed:
--   nvim --clean --headless -l <this file>
-- run from inside the worktree (the store resolves its path from the cwd).
-- Writes every annotation with no resolution row to a feedback file, marks
-- those records sent, and prints the file's path. Prints nothing when every
-- annotation is answered. Exits 1 with the reason on stderr on failure.

local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.abspath(arg[0] or debug.getinfo(1, "S").source:sub(2))))))
vim.opt.runtimepath:prepend(root)

-- `--clean` skips the user's config, which defines the `Config` global that
-- store.lua registers its DirChanged handler through.
if _G.Config == nil then
  _G.Config = { on = function() end }
end

local Store = require("config.annotations.store")
local Export = require("config.annotations.export")

if not Store.git_dir(vim.uv.cwd()) then
  io.stderr:write("Not inside a git worktree\n")
  vim.cmd("1cquit")
end

local unanswered = Store.unanswered()
if #unanswered == 0 then
  vim.cmd("0cquit")
end

local path, batch = Export.write(unanswered, vim.uv.cwd())
if not path then
  io.stderr:write(batch .. "\n")
  vim.cmd("1cquit")
end

local ids = {}
for _, rec in ipairs(unanswered) do
  table.insert(ids, rec.id)
end
Store.mark_sent(ids, batch)

io.stdout:write(path .. "\n")
vim.cmd("0cquit")
