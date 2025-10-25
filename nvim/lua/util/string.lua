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

---@class TitlePathOpts
---@field cwd string?
---@field target_width number?
---@field ambiguous_filetypes string[]?
---@field ambiguous_segments string[]?
---@field nextjs_segment_patterns string[]?

---@type TitlePathOpts
local DEFAULT_TITLE_PATH_OPTS = {
  ambiguous_filetypes = {
    "init.lua",
    "index.js",
    "index.ts",
    "index.jsx",
    "index.tsx",
    "package.json",
    "init.rs",
    "lib.rs",
    "main.rs",
    "README.md",
  },

  ambiguous_segments = {
    "src",
    "test",
    "tests",
    "__tests__",
  },

  nextjs_segment_patterns = {
    -- Nested files
    "/?app/.*/page%.([jt]sx?)$",
    "/?app/.*/default%.([jt]sx?)$",
    "/?app/.*/forbidden%.([jt]sx?)$",
    "/?app/.*/not%-found%.([jt]sx?)$",
    "/?app/.*/unauthorized%.([jt]sx?)$",
    "/?app/.*/layout%.([jt]sx?)$",
    "/?app/.*/loading%.([jt]sx?)$",
    "/?app/.*/error%.([jt]sx?)$",
    "/?app/.*/template%.([jt]sx?)$",
    "/?app/.*/route%.([jt]sx?)$",

    -- MDX files
    "/?app/.*/page%.mdx?$",
    "/?app/.*/default%.mdx?$",
    "/?app/.*/forbidden%.mdx?$",
    "/?app/.*/not%-found%.mdx?$",
    "/?app/.*/unauthorized%.mdx?$",
    "/?app/.*/loading%.mdx?$",
    "/?app/.*/error%.mdx?$",
  },
}

StringUtil.SEP = package.config:sub(1, 1)

---param path string
---param patterns? string[] List of Lua patterns to match against the path. Defaults to
---the patterns defined in DEFAULT_TITLE_PATH_OPTS.nextjs_segment_patterns.
function StringUtil.matches_any_pattern(path, patterns)
  patterns = patterns or DEFAULT_TITLE_PATH_OPTS.nextjs_segment_patterns
  for _, pat in ipairs(patterns) do
    if path:match(pat) then
      return true
    end
  end
  return false
end

--- @param path string?
--- @param opts? TitlePathOpts Options for title path to be merged with default options.
function StringUtil.title_path(path, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, DEFAULT_TITLE_PATH_OPTS)
  path = StringUtil.smart_shorten_path(path, { cwd = opts.cwd, target_width = opts.target_width })

  local segments = vim.split(path, StringUtil.SEP)
  local titlepath = {}

  -- Next.js segment pattern disambiguation
  if StringUtil.matches_any_pattern(path, opts.nextjs_segment_patterns) then
    for i = #segments, 1, -1 do
      if segments[i] == "app" then
        for j = i + 1, #segments do
          table.insert(titlepath, segments[j])
        end
        break
      end
    end
  else
    local filename = segments[#segments]
    segments[#segments] = nil -- Remove the filename from segments

    for i = #segments, 1, -1 do
      if i > 1 and vim.list_contains(opts.ambiguous_segments, segments[i]) then
        for j = i - 1, #segments do
          table.insert(titlepath, segments[j])
        end
        table.insert(titlepath, filename)
        break
      end
    end

    if #titlepath == 0 then
      if #segments and vim.list_contains(opts.ambiguous_filetypes, filename) then
        titlepath = { segments[#segments], filename }
      else
        titlepath = { filename }
      end
    end
  end

  titlepath = vim.tbl_filter(function(s)
    return s ~= nil and s ~= ""
  end, titlepath)

  return table.concat(titlepath, StringUtil.SEP)
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
