-- Builds the feedback markdown sent to Claude: one section per annotation,
-- with the code context it was left on and the annotation body underneath.

local Export = {}

local CONTEXT = 3

-- Applies configuration from `config/annotations/init.lua`: how many lines
-- of surrounding code to show above and below each annotated range.
---@param opts { context_lines?: integer }
function Export.configure(opts)
  opts = opts or {}
  if opts.context_lines then
    CONTEXT = opts.context_lines
  end
end

local function git_output(args, cwd)
  local result = vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout or "")
end

---@param toplevel string
---@param file string repo-relative
---@return string[] lines
local function read_lines(toplevel, file)
  local abs = vim.fs.joinpath(toplevel, file)
  local buf = vim.fn.bufnr(abs)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
  if vim.fn.filereadable(abs) == 1 then
    return vim.fn.readfile(abs)
  end
  return {}
end

local function filetype_for(toplevel, file)
  local abs = vim.fs.joinpath(toplevel, file)
  local buf = vim.fn.bufnr(abs)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    local ft = vim.bo[buf].filetype
    if ft and ft ~= "" then
      return ft
    end
  end
  return vim.filetype.match({ filename = file }) or ""
end

---@param toplevel string
---@return string?
local function git_dir_for(toplevel)
  local out = git_output({ "rev-parse", "--git-dir" }, toplevel)
  if not out then
    return nil
  end
  if out:sub(1, 1) ~= "/" then
    out = vim.fs.joinpath(toplevel, out)
  end
  return vim.fs.normalize(out)
end

---@param toplevel string
---@param batch string
---@return string
local function header(toplevel, batch)
  local head = git_output({ "rev-parse", "HEAD" }, toplevel) or "unknown"
  local branch = git_output({ "rev-parse", "--abbrev-ref", "HEAD" }, toplevel) or "unknown"
  local git_dir = git_dir_for(toplevel)
  -- Names the file the skill appends resolution rows to, so it doesn't have
  -- to recompute the git dir itself.
  local resolutions = git_dir and vim.fs.joinpath(git_dir, "claude-annotations", "resolutions.jsonl") or "unknown"
  return table.concat({
    "# Annotations",
    "",
    "Repo: " .. toplevel,
    "HEAD: " .. head,
    "Branch: " .. branch,
    "Batch: " .. batch,
    "Resolutions: " .. resolutions,
    "",
  }, "\n")
end

---@param rec Config.Annotations.Record
---@param toplevel string
---@return string
local function render_one(rec, toplevel)
  local lines = read_lines(toplevel, rec.file)
  local ft = filetype_for(toplevel, rec.file)
  local end_lnum = rec.end_lnum or rec.lnum

  local from = math.max(1, rec.lnum - CONTEXT)
  local to = math.min(#lines, end_lnum + CONTEXT)

  local loc = rec.file .. ":" .. rec.lnum
  if end_lnum ~= rec.lnum then
    loc = loc .. "-" .. end_lnum
  end

  local out = { string.format("## %s  (id: %s)", loc, rec.id), "" }
  table.insert(out, "```" .. ft)
  for lnum = from, to do
    local gutter = (lnum >= rec.lnum and lnum <= end_lnum) and "> " or "  "
    table.insert(out, gutter .. (lines[lnum] or ""))
  end
  table.insert(out, "```")
  table.insert(out, "")
  table.insert(out, rec.body)
  table.insert(out, "")
  return table.concat(out, "\n")
end

-- Builds the full feedback markdown for `records`, one section per record,
-- grouped in the order given.
---@param records Config.Annotations.Record[]
---@param toplevel string
---@param batch string
---@return string
function Export.render(records, toplevel, batch)
  local sections = { header(toplevel, batch) }
  for _, rec in ipairs(records) do
    table.insert(sections, render_one(rec, toplevel))
  end
  return table.concat(sections, "\n")
end

return Export
