local wezterm = require("wezterm")

local config = {}

config.check_for_updates = true
-- config.term = "wezterm"

config.color_scheme = "laserwave"
config.font = wezterm.font({ family = "MonoLisa Variable", weight = "Medium" })
config.font_size = 14.0
-- config.line_height = 1.0
-- config.freetype_load_flags = "NO_HINTING"
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

config.force_reverse_video_cursor = true
config.use_fancy_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.show_tab_index_in_tab_bar = false

config.mouse_wheel_scrolls_tabs = false

config.window_padding = {
	left = 6,
	right = 6,
	top = 14,
	bottom = 0,
}

-- This function returns the suggested title for a tab.
-- It prefers the title that was set via `tab:set_title()`
-- or `wezterm cli set-tab-title`, but falls back to the
-- title of the active pane in that tab.
local function tab_title(tab_info)
	local title = tab_info.tab_title
	-- if the tab title is explicitly set, take that
	if title and #title > 0 then
		return title
	end
	-- Otherwise, use the title from the active pane
	-- in that tab
	return tab_info.active_pane.title
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local title = tab_title(tab)
	if tab.is_active then
		return {
			{ Foreground = { Color = "magenta" } },
			{ Text = "   " },
			{ Foreground = { Color = "default" } },
			{ Text = title .. " " },
		}
	end
	return "   " .. title .. " "
end)

config.tab_max_width = 40

-- Allow <A-*> bindings in neovim
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- Allow <C-*> bindings in neovim
config.use_dead_keys = false

config.audible_bell = "Disabled"

config.native_macos_fullscreen_mode = true

config.prefer_to_spawn_tabs = true

config.enable_kitty_keyboard = true

config.adjust_window_size_when_changing_font_size = false

config.disable_default_key_bindings = true

local function is_inside_vim(pane)
	local tty = pane:get_tty_name()
	if tty == nil then
		return false
	end

	local success, stdout, stderr = wezterm.run_child_process({
		"sh",
		"-c",
		"ps -o state= -o comm= -t"
			.. wezterm.shell_quote_arg(tty)
			.. " | "
			.. "grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?)(diff)?$'",
	})

	return success
end

local function is_outside_vim(pane)
	return not is_inside_vim(pane)
end

local function bind_if(cond, key, mods, action)
	local function callback(win, pane)
		if cond(pane) then
			win:perform_action(action, pane)
		else
			win:perform_action(wezterm.action.SendKey({ key = key, mods = mods }), pane)
		end
	end

	return { key = key, mods = mods, action = wezterm.action_callback(callback) }
end

config.keys = {
	{ key = "q", mods = "CMD", action = wezterm.action.QuitApplication },
	{ key = "r", mods = "CMD|SHIFT", action = wezterm.action.ReloadConfiguration },
	{ key = "f", mods = "CTRL|CMD", action = wezterm.action.ToggleFullScreen },

	{ key = "k", mods = "CMD", action = wezterm.action.ScrollToBottom },
	{ key = "r", mods = "CMD|OPT", action = wezterm.action.ClearScrollback("ScrollbackAndViewport") },

	-- modes
	{ key = "p", mods = "CMD", action = wezterm.action.ActivateCommandPalette },
	{ key = "x", mods = "CMD", action = wezterm.action.ActivateCopyMode },
	-- { key = "l", mods = "CMD|SHIFT", action = wezterm.action.ShowDebugOverlay },
	{ key = "f", mods = "CMD", action = wezterm.action.Search({ CaseSensitiveString = "" }) },
	{ key = "/", mods = "CMD", action = wezterm.action.QuickSelect },

	-- Scrolling
	{ key = "PageUp", mods = "CMD|OPT", action = wezterm.action.ScrollByLine(-1) },
	{ key = "UpArrow", mods = "CMD", action = wezterm.action.ScrollByLine(-1) },
	{ key = "PageDown", mods = "CMD|OPT", action = wezterm.action.ScrollByLine(1) },
	{ key = "DownArrow", mods = "CMD", action = wezterm.action.ScrollByLine(1) },
	{ key = "PageUp", mods = "CMD", action = wezterm.action.ScrollByPage(-1) },
	{ key = "PageDown", mods = "CMD", action = wezterm.action.ScrollByPage(1) },
	{ key = "Home", mods = "CMD", action = wezterm.action.ScrollToTop },
	{ key = "End", mods = "CMD", action = wezterm.action.ScrollToBottom },

	-- Shell integration
	-- { key = "g", mods = "CMD|SHIFT", action = wezterm.action.ScrollToPrompt(-1) },
	{ key = "z", mods = "CMD|SHIFT", action = wezterm.action.ScrollToPrompt(-1) },
	{ key = "x", mods = "CMD|SHIFT", action = wezterm.action.ScrollToPrompt(1) },
	{ key = "s", mods = "CMD|SHIFT", action = wezterm.action.ActivateCopyMode },

	-- Font size
	{ key = "+", mods = "CMD", action = wezterm.action.IncreaseFontSize },
	{ key = "=", mods = "CMD", action = wezterm.action.IncreaseFontSize },
	{ key = "=", mods = "CMD|SHIFT", action = wezterm.action.IncreaseFontSize },
	{ key = "-", mods = "CMD", action = wezterm.action.DecreaseFontSize },
	{ key = "-", mods = "CMD|SHIFT", action = wezterm.action.DecreaseFontSize },
	{ key = "0", mods = "CMD", action = wezterm.action.ResetFontSize },

	-- Clipboard
	{ key = "c", mods = "CMD", action = wezterm.action.CopyTo("Clipboard") },
	{ key = "v", mods = "CMD", action = wezterm.action.PasteFrom("Clipboard") },

	-- Pane
	{ key = "w", mods = "CMD", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	{ key = "n", mods = "CMD", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- Tab
	{ key = "t", mods = "CMD|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "l", mods = "CMD|SHIFT", action = wezterm.action.ActivateTabRelative(1) },
	{ key = "]", mods = "CMD", action = wezterm.action.ActivateTabRelative(1) },
	{ key = "]", mods = "CMD|SHIFT", action = wezterm.action.MoveTabRelative(1) },
	{ key = "h", mods = "CMD|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
	{ key = "[", mods = "CMD", action = wezterm.action.ActivateTabRelative(-1) },
	{ key = "[", mods = "CMD|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
	{ key = "w", mods = "CMD|SHIFT", action = wezterm.action.CloseCurrentTab({ confirm = true }) },

	-- Window
	{ key = "n", mods = "CMD|SHIFT", action = wezterm.action.SpawnWindow },
	bind_if(is_outside_vim, "h", "CTRL", wezterm.action.ActivatePaneDirection("Left")),
	bind_if(is_outside_vim, "l", "CTRL", wezterm.action.ActivatePaneDirection("Right")),
	bind_if(is_outside_vim, "j", "CTRL", wezterm.action.ActivatePaneDirection("Down")),
	bind_if(is_outside_vim, "k", "CTRL", wezterm.action.ActivatePaneDirection("Up")),

	-- TODO: Basic toggle-term-like behavior but with a wezterm pane instead.
	-- eg, from kitty config:
	-- map cmd+t kitten toggle_term.py cwd
	-- map cmd+n kitten toggle_term.py new cwd
	-- map shift+cmd+d close_window
	-- map cmd+r start_resizing_window
	-- map cmd+m swap_with_window
	-- map shift+cmd+m detach_window ask

	-- TODO: Explore layouts when https://github.com/wez/wezterm/issues/3516 lands
}

return config
