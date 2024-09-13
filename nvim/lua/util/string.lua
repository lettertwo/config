---@class StringUtil
local StringUtil = {}

---@param str string
function StringUtil.capcase(str)
  return str:sub(1, 1):upper() .. str:sub(2)
end

---@param str string
---@param group string
function StringUtil.format_highlight(str, group)
  return "%#" .. group .. "#" .. str .. "%*"
end

--- @param path string?
--- @param opts? { cwd: string?, target_width: number? }
function StringUtil.smart_shorten_path(path, opts)
  opts = opts or {}
  local cwd = opts.cwd
  local target_width = opts.target_width

  local Path = require("plenary.path")
  local truncate = require("plenary.strings").truncate

  if path == nil then
    path = vim.api.nvim_buf_get_name(0)
  end

  path = Path:new(path):normalize(cwd or vim.loop.cwd())

  if target_width ~= nil then
    if #path > target_width then
      path = Path:new(path):shorten(1, { -2, -1 })
    end

    if #path > target_width then
      path = Path:new(path):shorten(1, { -1 })
    end

    if #path > target_width then
      path = truncate(path, target_width, nil, -1)
    end
  end

  return path
end

local DEFAULT_TITLE_PATH_OPTS = {
  ambiguous_segments = {
    "init.lua",
    "index.js",
    "index.ts",
    "index.jsx",
    "index.tsx",
    "package.json",
    "init.rs",
    "lib.rs",
    "main.rs",
    "src",
  },
}

StringUtil.SEP = package.config:sub(1, 1)

--- @param path string?
--- @param opts? { cwd: string?, target_width: number?, ambiguous_segments: string[]? }
function StringUtil.title_path(path, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, DEFAULT_TITLE_PATH_OPTS)
  path = StringUtil.smart_shorten_path(path, { cwd = opts.cwd, target_width = opts.target_width })

  local segments = vim.split(path, StringUtil.SEP)

  local title_path = {}

  local i = #segments

  while i > 0 do
    local segment = segments[i]
    table.insert(title_path, 1, segment)
    if not vim.list_contains(opts.ambiguous_segments, segment) then
      break
    end
    i = i - 1
  end

  return table.concat(title_path, StringUtil.SEP)
end

function StringUtil.timeago(time)
  local current_time = os.time()
  local time_difference = os.difftime(current_time, time)
  local minutes = math.floor(time_difference / 60)
  local hours = math.floor(time_difference / 3600)
  local days = math.floor(time_difference / 86400)

  if days > 0 then
    return days .. (days > 1 and " days ago" or " day ago")
  elseif hours > 0 then
    return hours .. (hours > 1 and " hours ago" or " hour ago")
  elseif minutes > 0 then
    return minutes .. (minutes > 1 and " minutes ago" or " minute ago")
  else
    return "just now"
  end
end

return StringUtil
