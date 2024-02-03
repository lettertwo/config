local Util = require("util")

local MRU = {}

local MRU_OPTS = {
  ignore_extensions = { "gitcommit" },
  show = 10,
  width = 44,
}

---@param fn string
---@return string
local function get_extension(fn)
  local match = fn:match("^.+(%..+)$")
  local ext = ""
  if match ~= nil then
    ext = match:sub(2)
  end
  return ext
end

---@param fn string
---@return string | nil, string | nil
local function icon(fn)
  local nwd_ok, nwd = pcall(require, "nvim-web-devicons")
  if not nwd_ok then
    return nil
  end
  local ext = get_extension(fn)
  return nwd.get_icon(fn, ext, { default = true })
end

---@param filepath string
---@param shortcut string
---@param display? string
---@return Button
function MRU.file_button(filepath, shortcut, display)
  display = display or filepath
  local ico_txt = ""
  local fb_hl = {}

  local ico, hl = icon(filepath)
  if ico ~= nil and hl ~= nil then
    table.insert(fb_hl, { hl, 0, #ico })
    ico_txt = ico .. "  "
  end

  local file_button_el = require("alpha.themes.dashboard").button(
    shortcut,
    ico_txt .. display,
    "<cmd>e " .. vim.fn.fnameescape(filepath) .. " <CR>"
  )
  local fn_start = display:match(".*[/\\]")
  if fn_start ~= nil then
    table.insert(fb_hl, { "Comment", #ico_txt - 2, #fn_start + #ico_txt })
  end
  file_button_el.opts.hl = fb_hl
  return file_button_el
end

---@param cwd string | boolean? `false` to ignore, `true` to use vim's cwd, or a string. Default: `true`.
---@return Element[]
function MRU.mru(cwd)
  if cwd == nil or cwd == true then
    cwd = vim.fn.getcwd()
  end

  local oldfiles = {}
  for _, filepath in pairs(vim.v.oldfiles) do
    if #oldfiles >= MRU_OPTS.show then
      break
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    local in_cwd = not cwd or vim.startswith(filepath, cwd)
    local ignore = not in_cwd
      or string.find(filepath, "COMMIT_EDITMSG")
      or vim.tbl_contains(MRU_OPTS.ignore_extensions, get_extension(filepath))

    local readable = vim.fn.filereadable(filepath) == 1

    if readable and not ignore then
      oldfiles[#oldfiles + 1] = filepath
    end
  end

  local val = {}
  for i, filepath in ipairs(oldfiles) do
    local display = Util.smart_shorten_path(filepath, { target_width = MRU_OPTS.width })
    local shortcut = tostring(i - 1)
    val[i] = MRU.file_button(filepath, shortcut, display)
  end

  return val
end

return MRU
