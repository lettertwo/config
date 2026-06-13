local function section_root()
  return "󱉭 " .. vim.fs.basename(Config.root("package"))
end

local function section_macro()
  local reg = vim.fn.reg_recording()
  return reg ~= "" and ("󰑋 " .. reg) or ""
end

local function section_branch()
  local head = vim.b.gitsigns_head
  if head and head ~= "" then
    return " " .. head
  end
  return ""
end

local function section_tabstop()
  return " 󰯉 " .. vim.bo.tabstop .. " "
end

local function section_tabs(mode_hl)
  local n_tabs = #vim.api.nvim_list_tabpages()
  if n_tabs <= 1 then
    return ""
  end
  local current = vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage())
  local active_hl = mode_hl
  local separator_hl = mode_hl .. "Inverted"
  local inactive_hl = "MiniStatuslineInactive"
  local separator = ""
  local parts = {}
  for i = 1, n_tabs do
    local label = " " .. i .. " "
    if i == current then
      table.insert(parts, Config.format_highlight(label, active_hl))
      if i < n_tabs then
        table.insert(parts, Config.format_highlight(separator, separator_hl))
      else
        table.insert(parts, Config.format_highlight(" ", active_hl))
      end
    else
      table.insert(parts, Config.format_highlight(label, inactive_hl))
      if i == current - 1 or i == n_tabs then
        table.insert(parts, Config.format_highlight(separator, active_hl))
      else
        table.insert(parts, Config.format_highlight(" ", inactive_hl))
      end
    end
  end
  return table.concat(parts, "")
end

local function section_mode()
  return MiniStatusline.section_mode({ trunc_width = 120 })
end

local function section_search()
  local count
  local icon = ""
  if vim.v.hlsearch == 0 then
    if package.loaded["occurrence"] ~= nil then
      local ok, occurrence = pcall(require, "occurrence")
      if ok and occurrence then
        ok, count = pcall(occurrence.status)
        if ok and count then
          icon = "󱡴 "
        end
      end
    end
  else
    local ok, result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 200 })
    if ok and result then
      count = result
      icon = "󰍉 "
    end
  end

  if not count or not count.current or not count.total then
    return ""
  end
  local denominator = math.min(count.total, 999)
  return string.format("%s[%d/%d]", icon, count.current, denominator)
end

local function section_filepath()
  local filepath = vim.fn.expand("%:~:.")
  if MiniStatusline.is_truncated(120) then
    return Config.title_path(filepath, { disambiguate = true })
  end
  return filepath
end

local function section_titlepath()
  local ok, MiniIcons = pcall(require, "mini.icons")
  local icon_str = ""
  if ok then
    local ft = vim.bo.filetype
    icon_str = MiniIcons.get("filetype", ft) .. " "
  end
  local name = vim.fn.expand("%:~:.")
  local path = name ~= "" and Config.title_path(name, { disambiguate = true }) or "[No Name]"
  return " " .. icon_str .. " " .. path
end

local function section_location()
  return "%l:%v"
end

local function section_services()
  local display = {}
  local status = Config.service_status()

  if status.debug_active then
    local dap_ok, dap = pcall(require, "dap")
    if dap_ok then
      table.insert(display, "  " .. dap.status())
    end
  end

  if #status.diagnostic_providers > 0 then
    table.insert(display, Config.icons.services.diagnostics .. #status.diagnostic_providers)
  end

  if #status.formatting_providers > 0 then
    table.insert(display, Config.icons.services.formatting .. #status.formatting_providers)
  end

  if status.copilot_active then
    table.insert(display, Config.icons.services.copilot)
  end

  if status.treesitter_active then
    table.insert(display, Config.icons.services.treesitter)
  end

  if status.session_active then
    table.insert(display, Config.icons.services.persisting)
  else
    table.insert(display, Config.icons.services.not_persisting)
  end

  if status.pack_updates > 0 then
    table.insert(display, " " .. status.pack_updates)
  end

  return table.concat(display, " ")
end

local function section_diff()
  local gs = vim.b.gitsigns_status_dict
  if not gs then
    return ""
  end
  local di = Config.icons.diff
  local parts = {}
  if (gs.added or 0) > 0 then
    table.insert(parts, Config.format_highlight(di.added .. gs.added, "Added"))
  end
  if (gs.changed or 0) > 0 then
    table.insert(parts, Config.format_highlight(di.modified .. gs.changed, "Changed"))
  end
  if (gs.removed or 0) > 0 then
    table.insert(parts, Config.format_highlight(di.removed .. gs.removed, "Removed"))
  end

  if #parts > 0 then
    table.insert(parts, 1, "")
    table.insert(parts, "")
  end

  return table.concat(parts, " ")
end

local function section_diagnostics()
  local di = Config.icons.diagnostics
  local counts = vim.diagnostic.count(0)
  local parts = {}
  if (counts[1] or 0) > 0 then
    table.insert(parts, Config.format_highlight(di.Error .. counts[1], "DiagnosticError"))
  end
  if (counts[2] or 0) > 0 then
    table.insert(parts, Config.format_highlight(di.Warn .. counts[2], "DiagnosticWarn"))
  end
  if (counts[3] or 0) > 0 then
    table.insert(parts, Config.format_highlight(di.Info .. counts[3], "DiagnosticInfo"))
  end
  if (counts[4] or 0) > 0 then
    table.insert(parts, Config.format_highlight(di.Hint .. counts[4], "DiagnosticHint"))
  end

  if #parts > 0 then
    table.insert(parts, 1, "")
    table.insert(parts, "")
  end

  return table.concat(parts, " ")
end

local function winbar_is_eligible(win)
  local config = vim.api.nvim_win_get_config(win)
  if config.relative ~= "" then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  return not vim.tbl_contains(Config.filetypes.ui, ft)
end

local WINBAR_CONTENT = "%{%(nvim_get_current_win()==#g:actual_curwin)"
  .. " ? v:lua.MiniStatusline.active_winbar()"
  .. " : v:lua.MiniStatusline.inactive_winbar()%}"

local function winbar_update()
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].winbar = winbar_is_eligible(win) and WINBAR_CONTENT or ""
end

---@class Config.MiniStatusline
local MiniStatuslineConfig = {}

-- Build a powerline-style winbar pill: colored label + right-pointing cap + WinBar bg.
-- hl_mode must be a MiniStatuslineMode* highlight group. Falls back to plain label
-- if the highlight isn't defined yet (e.g. standalone app before setup_highlights runs).
function MiniStatuslineConfig.make_winbar(label, hl_mode)
  local hl = vim.api.nvim_get_hl(0, { name = hl_mode })
  if next(hl) then
    return table.concat({
      "%#" .. hl_mode .. "#",
      label,
      " %#" .. hl_mode .. "Inverted#",
      "\u{E0B0}",
      "%#WinBar#",
    })
  else
    return label
  end
end

-- Set MiniStatusline* highlight groups from the active lualine theme.
-- Safe to call from standalone apps; idempotent (skips already-defined groups).
-- Registers a ColorScheme autocmd so highlights survive theme changes.
function MiniStatuslineConfig.setup_highlights()
  local colors_name = vim.g.colors_name
  if not colors_name then
    return
  end

  -- Try to load the corresponding lualine theme
  local ok, theme = pcall(require, "lualine.themes." .. colors_name)
  if not (ok and theme and theme.normal) then
    return
  end

  ---@param section 'normal' | 'insert' | 'command' | 'visual' | 'replace' | 'select' | 'terminal' | 'terminal_normal' | 'inactive'
  ---@param sub 'a' | 'b' | 'c' | 'x' | 'y' | 'z'
  ---@param opts? vim.api.keyset.highlight | { inverted: boolean }
  ---@return vim.api.keyset.highlight?
  local function section_hl(section, sub, opts)
    local src = (theme[section] and theme[section][sub]) or (theme.normal and theme.normal[sub])
    if not src then
      return nil
    end
    local inverted = opts and opts.inverted
    if opts then
      opts.inverted = nil
    end

    return vim.tbl_extend("keep", opts or {}, inverted and { fg = src.bg, bg = src.fg } or { fg = src.fg, bg = src.bg })
  end

  ---@param section 'normal' | 'insert' | 'command' | 'visual' | 'replace' | 'select' | 'terminal' | 'terminal_normal' | 'inactive'
  ---@param opts? vim.api.keyset.highlight | { inverted: boolean }
  ---@return vim.api.keyset.highlight?
  local function mode_hl(section, opts)
    return section_hl(section, "a", opts)
  end

  ---@param name string
  ---@param val? vim.api.keyset.highlight
  local set = function(name, val)
    if val and next(vim.api.nvim_get_hl(0, { name = name, create = false })) == nil then
      vim.api.nvim_set_hl(0, name, val)
    end
  end

  set("MiniStatuslineModeNormal", mode_hl("normal"))
  set("MiniStatuslineModeNormalInverted", mode_hl("normal", { inverted = true }))
  set("MiniStatuslineModeInsert", mode_hl("insert"))
  set("MiniStatuslineModeInsertInverted", mode_hl("insert", { inverted = true }))
  set("MiniStatuslineModeVisual", mode_hl("visual"))
  set("MiniStatuslineModeVisualInverted", mode_hl("visual", { inverted = true }))
  set("MiniStatuslineModeReplace", mode_hl("replace"))
  set("MiniStatuslineModeReplaceInverted", mode_hl("replace", { inverted = true }))
  set("MiniStatuslineModeCommand", mode_hl("command"))
  set("MiniStatuslineModeCommandInverted", mode_hl("command", { inverted = true }))
  set("MiniStatuslineModeOther", mode_hl("terminal"))
  set("MiniStatuslineModeOtherInverted", mode_hl("terminal", { inverted = true }))

  set("MiniStatuslineDevinfo", section_hl("normal", "b"))
  set("MiniStatuslineFilename", section_hl("normal", "c"))
  set("MiniStatuslineFileinfo", section_hl("normal", "b"))
  set("MiniStatuslineInactive", section_hl("inactive", "c"))
end

function MiniStatuslineConfig.setup()
  Config.add("nvim-mini/mini.nvim")

  local MiniStatusline = require("mini.statusline")

  -- Apply before mini.setup so our autocmd fires before mini's ColorScheme autocmd,
  -- and so mini's default = true highlights don't win over our lualine values at startup.
  MiniStatuslineConfig.setup_highlights()
  Config.on("ColorScheme", MiniStatuslineConfig.setup_highlights)

  MiniStatusline.setup({
    content = {
      active = function()
        local mode, mode_hl = section_mode()
        local mode_hl_inverted = mode_hl .. "Inverted"

        return MiniStatusline.combine_groups({
          section_tabs(mode_hl),
          { hl = mode_hl, strings = { mode, section_search() } },
          { hl = mode_hl_inverted },
          "",
          { hl = "Error", strings = { section_macro() } },
          { hl = "MiniStatuslineDevinfo", strings = { section_branch() } },
          { hl = "MiniStatuslineDevinfo", strings = { section_root() } },
          "%<", -- Mark general truncate point
          { hl = "MiniStatuslineFilename", strings = { section_filepath(), section_location() } },
          "%=", -- End left alignment
          section_diff(),
          section_diagnostics(),
          section_tabstop(),
          { hl = mode_hl_inverted },
          "",
          { hl = mode_hl, strings = { section_services() } },
        })
      end,
    },
  })

  -- Winbar render functions exposed on MiniStatusline so v:lua can reach them
  -- from the per-window winbar format string (same mechanism as the statusline).
  function MiniStatusline.active_winbar()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local modified = vim.bo[buf].modified and " ●" or ""
    local _, mode_hl = section_mode()
    local mode_hl_inverted = mode_hl .. "Inverted"
    return MiniStatusline.combine_groups({
      { hl = mode_hl, strings = { section_titlepath(), modified } },
      { hl = mode_hl_inverted },
      "",
      { hl = "WinBar" },
    })
  end

  function MiniStatusline.inactive_winbar()
    return MiniStatusline.combine_groups({
      { hl = "WinBarNC", strings = { section_titlepath() } },
    })
  end

  Config.on({ "WinEnter", "BufEnter", "FileType" }, winbar_update)
end

return MiniStatuslineConfig
