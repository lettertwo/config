-- Line-anchored code annotations, sent as a batch to a Claude Code session
-- running in another kitty window. `store.lua` persists them, `anchor.lua`
-- draws them, `export.lua` builds the feedback file, `send.lua` delivers it,
-- `watch.lua` reloads the store when the Claude side writes a resolution,
-- `ui.lua` holds the actions this module binds to keys.

local Anchor = require("config.annotations.anchor")
local Export = require("config.annotations.export")
local Send = require("config.annotations.send")
local Watch = require("config.annotations.watch")

local Annotations = {}

local DEFAULT_KEYMAPS = {
  ["<leader>aa"] = "add",
  ["<leader>ae"] = "edit",
  ["<leader>ad"] = "delete",
  ["<leader>ax"] = "dismiss",
  ["<leader>ar"] = "resolve",
  ["<leader>al"] = "list",
  ["<leader>at"] = "toggle_body",
  ["<leader>ab"] = "toggle_background",
  ["<leader>as"] = "send",
  ["<leader>aC"] = "clear_resolved",
  ["]a"] = "next",
  ["[a"] = "prev",
}

-- `add` is the only action meaningful from a visual range, so it's the only
-- one mapped in both modes; everything else only makes sense at the cursor.
local ACTION_MODES = { add = { "n", "x" } }

local defaults = {
  keymaps = DEFAULT_KEYMAPS,
  signs = {
    pending = "▶",
    sent = "▸",
    connector = "│",
    branch = "├",
    range_end = "╵",
    resolved_changed = "✓",
    resolved_unchanged = "–",
  },
  show_body = true,
  show_background = false,
  context_lines = 3,
  kitty_socket = nil,
}

local started = false

local function bind(lhs, action)
  local modes = ACTION_MODES[action] or { "n" }
  for _, mode in ipairs(modes) do
    if mode == "x" and action == "add" then
      vim.keymap.set("x", lhs, function()
        -- Leaving visual mode first sets the '< / '> marks this reads.
        vim.cmd("normal! \27")
        local line1, line2 = vim.fn.line("'<"), vim.fn.line("'>")
        require("config.annotations.ui").add({ line1 = line1, line2 = line2 })
      end, { desc = "Annotate range" })
    else
      vim.keymap.set(mode, lhs, function()
        require("config.annotations.ui")[action]()
      end, { desc = "Annotation: " .. action })
    end
  end
end

---@param opts? table
function Annotations.setup(opts)
  if started then
    return
  end
  started = true
  opts = vim.tbl_deep_extend("force", defaults, opts or {})

  Anchor.configure({
    signs = opts.signs,
    show_body = opts.show_body,
    show_background = opts.show_background,
  })
  Export.configure({ context_lines = opts.context_lines })
  Send.configure({ kitty_socket = opts.kitty_socket })

  Anchor.setup()
  Watch.start()
  Config.on("User", "AnnotationsChanged", function()
    if not Watch.active() then
      Watch.start()
    end
  end, "Start the annotation directory watcher once the directory exists")
  Config.on("DirChanged", function()
    Watch.start()
  end, "Re-point the annotation directory watcher after cd")
  Config.on("VimLeavePre", Watch.stop, "Stop the annotation directory watcher")

  for lhs, action in pairs(opts.keymaps) do
    bind(lhs, action)
  end
end

-- Test-only: lets a spec call `setup` again with different options.
function Annotations._reset()
  started = false
end

return Annotations
