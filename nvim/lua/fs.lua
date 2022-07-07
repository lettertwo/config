local readdir = vim.fn.readdir
local isdir = vim.fn.isdirectory
local exists = vim.fn.exists

local path_sep = vim.loop.os_uname().version:match "Windows" and "\\" or "/"

local function join_paths(...)
  return table.concat({ ... }, path_sep)
end

local function to_module_name(path)
  return path
    :gsub(join_paths(".*", "lua", ""), "")             -- trim **/lua/ from front of path
    :gsub(join_paths("", "init.lua$"), "")              -- trim /init.lua from end of path
    :gsub(".lua$", "")                                 -- trim .lua from end of path
    :gsub(path_sep, ".")                               -- replace path separators with dots
end

local function is_module(pathname)
  if pathname:match(".lua$") then
    return true
  end
  if exists(join_paths(pathname, "index.lua")) then
    return true
  end
  return false
end

local function walk_modules(root)
  local queue = {}
  for _, v in ipairs(readdir(root)) do
    table.insert(queue, join_paths(root, v))
  end
  return function()
    while #queue > 0 do
      local head = table.remove(queue, 1)
      if head == nil then
        return nil
      elseif is_module(head) then
        return to_module_name(head)
      elseif isdir(head) then
        for i, v in ipairs(readdir(head)) do
          table.insert(queue, i, join_paths(head, v))
        end
      end
    end
  end
end

return {
  path_sep = path_sep,
  join_paths = join_paths,
  is_module = is_module,
  walk_modules = walk_modules,
}