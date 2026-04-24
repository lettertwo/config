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

function actions.toggle_cwd(p)
  local root = Config.root()
  local cwd = vim.fs.normalize((vim.uv or vim.loop).cwd() or ".")
  local current = p:cwd()
  p:set_cwd(current == root and cwd or root)
  p:find()
end

function actions.mini_files(picker, item)
  picker:close()

  local filepath = Snacks.picker.util.path(item)
  if filepath then
    local ok, MiniFiles = pcall(require, "mini.files")
    if ok and MiniFiles then
      local open_ok = pcall(MiniFiles.open, filepath)
      if not open_ok then
        Snacks.notify.warn("Failed to open file in mini.files", { title = picker.title })
      end
    else
      Snacks.notify.warn("mini.files is not installed", { title = picker.title })
    end
  else
    Snacks.notify.warn("No file to open", { title = picker.title })
  end
end

function actions.help_or_readme(picker, item)
  picker:close()
  if not item then
    vim.notify("Could not open help or readme.", vim.log.levels.ERROR)
    return
  end

  -- defer so picker window teardown completes before :help searches for an
  -- existing help window to reuse (picker:close() schedules async cleanup)
  vim.schedule(function()
    -- find an existing help or readme window to reuse
    local reuse_win, reuse_buf
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "help" or (vim.bo[buf].buftype == "" and vim.b[buf].readme) then
        reuse_win, reuse_buf = win, buf
        break
      end
    end

    -- :help only reuses windows with buftype=help, so if we found a readme
    -- window, briefly mark it as help so :help lands there instead of splitting
    local patched = reuse_buf and vim.b[reuse_buf].readme
    if patched then
      vim.bo[reuse_buf].modifiable = true
      vim.bo[reuse_buf].readonly = false
      vim.bo[reuse_buf].buftype = "help"
    end

    local ok = item.name and pcall(vim.cmd.help, item.name)

    -- if help failed, undo the patch so the readme window is left intact
    if not ok and patched and vim.api.nvim_buf_is_valid(reuse_buf) then
      vim.bo[reuse_buf].buftype = ""
      vim.bo[reuse_buf].readonly = true
      vim.bo[reuse_buf].modifiable = false
    end

    -- fallback: look for README file in the plugin dir
    if not ok then
      local dir = Snacks.picker.util.path(item)
      if not dir then
        vim.notify("Could not open help or readme.", vim.log.levels.ERROR)
        return
      end

      local readme = nil
      local handle = vim.uv.fs_scandir(dir)
      while handle do
        local name, type = vim.uv.fs_scandir_next(handle)
        if not name then
          break
        end
        if type == "file" then
          local ext = vim.fs.ext(name)
          local base = string.lower(#ext and string.sub(name, 1, #name - #ext - 1) or name)
          if base == "readme" then
            readme = vim.fs.joinpath(dir, name)
            break
          end
        end
      end

      if readme then
        ok = pcall(function()
          if reuse_win then
            vim.api.nvim_set_current_win(reuse_win)
            vim.cmd.edit(vim.fn.fnameescape(readme))
          else
            vim.cmd.split(vim.fn.fnameescape(readme))
          end
          local buf = vim.api.nvim_get_current_buf()
          vim.b[buf].readme = true
          vim.bo[buf].readonly = true
          vim.bo[buf].modifiable = false
          vim.bo[buf].buflisted = false
        end)
      end
    end

    if not ok then
      vim.notify("Could not open help or readme.", vim.log.levels.ERROR)
    end
  end)
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
