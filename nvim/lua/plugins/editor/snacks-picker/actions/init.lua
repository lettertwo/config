---@module "snacks"
---@type table<string, snacks.picker.Action.spec>
local actions = {}

function actions.close_normal(picker)
  picker:close()
  if vim.fn.mode():sub(1, 1) == "i" then
    vim.cmd.stopinsert()
    return
  end
end

function actions.smart_scroll_down(picker)
  if not pcall(picker.preview.win.scroll, picker.preview.win) then
    picker.list:scroll(picker.list.state.scroll)
  end
end

function actions.smart_scroll_up(picker)
  if not pcall(picker.preview.win.scroll, picker.preview.win, true) then
    picker.list:scroll(-picker.list.state.scroll)
  end
end

function actions.reveal_in_oil(picker, item)
  picker:close()

  local ok, oil = pcall(require, "oil")
  if ok and oil then
    local dir = Snacks.picker.util.dir(item)
    if dir then
      local basename = vim.fs.basename(Snacks.picker.util.path(item))
      local open_ok = pcall(oil.open_float, dir, { preview = { horizontal = true } }, function()
        --- select the item in oil
        vim.fn.search("\\V" .. basename, "w")
      end)
      if not open_ok then
        Snacks.notify.warn("Failed to open file in oil", { title = picker.title })
      end
    else
      Snacks.notify.warn("No file to open", { title = picker.title })
    end
  else
    Snacks.notify.warn("oil is not installed", { title = picker.title })
  end
end

function actions.help_or_readme(picker, item)
  picker:close()
  local ok = false
  if item then
    ok = item.name and pcall(vim.cmd.help, item.name)
    if not ok then
      local filepath = Snacks.picker.util.path(item)
      if not filepath then
        return nil
      end
      local readme = nil
      LazyVim.ls(filepath, function(path, name, type)
        if type == "file" then
          local index = string.find(name, "%.")
          if index then
            local n = string.sub(name, 1, index - 1)
            if string.lower(n) == "readme" then
              readme = path
              return false
            end
          end
        end
      end)
      if readme then
        ok = pcall(vim.cmd.edit, readme)
      end
    end
  end
  if not ok then
    vim.notify("Could not open help or readme.", vim.log.levels.ERROR)
  end
end

-- TODO: check for builtin version of this
function actions.chdir(picker, item)
  picker:close()
  if item and item.dir then
    if vim.fn.getcwd() == item.dir then
      return
    end
    local path = vim.fn.fnameescape(item.dir)
    local ok, res = pcall(vim.cmd.cd, path)
    if ok then
      vim.notify(string.format("Changed cwd to: '%s'.", path), vim.log.levels.INFO)
    else
      vim.notify(string.format("Could not change cwd to: '%s'. Error: '%s'", path, res), vim.log.levels.ERROR)
    end
  end
end

-- TODO: Check for builtin version of this
-- TODO: open kitty terminal instead of builtin
function actions.open_in_terminal(picker, item)
  picker:close()
  if item and item.dir then
    vim.cmd("terminal cd " .. vim.fn.fnameescape(item.dir))
  end
end

-- TODO: Check for builtin version of this
function actions.open_in_browser(picker, item)
  picker:close()
  if item and item.url then
    vim.notify("Opening in browser: " .. item.url, vim.log.levels.INFO)
    vim.fn.jobstart({ "open", item.url }, { detach = true })
  end
end

-- TODO: Check for builtin version of this
function actions.find_files(picker, item) end

-- TODO: Check for builtin version of this
function actions.grep(picker, item) end

function actions.yank_to_clipboard(picker)
  picker:close()
  local items = picker:selected({ fallback = true })

  local yanked = {}
  for _, item in ipairs(items) do
    if item then
      if item.file then
        yanked[#yanked + 1] = tostring(item.file)
      elseif item.url then
        yanked[#yanked + 1] = tostring(item.url)
      elseif item.name then
        yanked[#yanked + 1] = tostring(item.name)
      elseif item.text then
        yanked[#yanked + 1] = tostring(item.text)
      else
        yanked[#yanked + 1] = tostring(item)
      end
    end
  end

  vim.fn.setreg("+", yanked)
  Snacks.notify.info(
    #yanked > 1 and "Yanked " .. #yanked .. " items to clipboard" or "Yanked item to clipboard",
    { title = picker.title }
  )
end

return actions
