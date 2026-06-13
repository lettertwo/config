-- The default app: normal editing experience.
-- This is the root app that runs for a plain `nvim` launch.
--
-- Two-phase lifecycle:
--   load()  — NOT defined here; the framework auto-scans lua/app/default/plugins/
--             alphabetically during init, registering FileType autocmds early
--             enough to catch the first argv buffer.
--   run()   — called on UIEnter. Handles layout / dashboard / session restore.
--   teardown() — called on VimLeavePre (standalone) or TabClosed (embedded).

---@type App
---@diagnostic disable-next-line: missing-fields
local DefaultApp = {
  name = "default",
}

function DefaultApp:run()
  require("config.mini.statusline").setup()
end

function DefaultApp:teardown()
  -- Nothing to clean up; nvim manages the normal exit lifecycle.
end

return DefaultApp
