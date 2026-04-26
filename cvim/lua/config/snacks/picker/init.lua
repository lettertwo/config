local map = vim.keymap.set

---@class Config.SnacksPicker
local SnacksPickerConfig = {}

function SnacksPickerConfig.config(opts)
  local Snacks = require("snacks")

  ---@module 'snacks'
  ---@type snacks.Config
  opts.picker = {
    icons = Config.icons,
    formatters = {
      file = { filename_first = true },
      selected = { show_always = false, unselected = true },
    },
    previewers = {
      diff = { builtin = false },
      git = { builtin = false },
    },
    actions = require("config.snacks.picker.actions"),
    layouts = require("config.snacks.picker.layouts"),
    sources = require("config.snacks.picker.sources"),
    layout = { preset = "mini" },
    win = {
      input = {
        -- stylua: ignore
        keys = {
          ["<Esc>"]   = { "close_normal",      mode = { "n", "i" } },
          ["<C-.>"]   = { "toggle_cwd",        mode = { "n", "i" } },
          ["<C-d>"]   = { "smart_scroll_down", mode = { "n", "i" } },
          ["<C-u>"]   = { "smart_scroll_up",   mode = { "n", "i" } },
          ["<C-e>"]   = { "mini_files",        mode = { "n", "i" } },
          ["<C-y>"]   = { "yank_to_clipboard", mode = { "n", "i" } },
          ["<C-c>"]   = { "toggle_cwd",        mode = { "n", "i" } },
          ["<C-/>"]   = { "toggle_help",       mode = { "n", "i" } },
          ["<S-C-/>"] = { "inspect",           mode = { "n", "i" } },
          ["<C-m>"]   = { "toggle_maximize",   mode = { "n", "i" } },
          ["<Tab>"]   = { "toggle_preview",    mode = { "n", "i" } },
          ["<c-w>"]   = { "cycle_win",         mode = { "n", "i" } },
          ["<C-p>"]   = { "history_back",      mode = { "n", "i" } },
          ["<C-n>"]   = { "history_forward",   mode = { "n", "i" } },
          ["<C-CR>"]  = { "select_and_next",   mode = { "n", "i" } },
          ["<C-i>"]   = { "toggle_ignored",    mode = { "n", "i" } },
          ["<C-h>"]   = { "toggle_hidden",     mode = { "n", "i" } },
        },
      },
    },
  }

  -- stylua: ignore start
  map("n", "<leader>fe", function() Snacks.explorer({ cwd = Config.root(), layout = { layout = { width = 0.3 } } }) end, { desc = "File Tree (root dir)" })
  map("n", "<leader>fE", function() Snacks.explorer({ layout = { layout = { width = 0.3 } } }) end, { desc = "File Tree (cwd)" })
  map("n", "<leader>E", "<leader>fE", { desc = "File Tree (cwd)", remap = true })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>f<space>", function() Snacks.picker.pick("pickers") end, { desc = "Find Pickers" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>f.", function() Snacks.picker.pick("files", { scope = "package" }) end, { desc = "Find Files (package)" })
  map("n", "<leader>fw", function() Snacks.picker.pick("files", { scope = "workspace" }) end, { desc = "Find Files (workspace)" })
  map("n", "<leader>ff", function() Snacks.picker.pick("files", { scope = "cwd" }) end, { desc = "Find Files (cwd)" })
  map("n", "<leader>fF", function() Snacks.picker.pick("files", { scope = "root" }) end, { desc = "Find Files (root dir)" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>fr", function() Snacks.picker.pick("recent", { scope = "workspace" }) end, { desc = "Recent (workspace)" })
  map("n", "<leader>fR", function() Snacks.picker.pick("recent", { scope = "root" }) end, { desc = "Recent (root)" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>sg", function() Snacks.picker.pick("grep", { scope = "workspace" }) end, { desc = "Grep (workspace)" })
  map("n", "<leader>sG", function() Snacks.picker.pick("grep", { scope = "root" }) end, { desc = "Grep (root)" })
  map("n", "<leader>s.", function() Snacks.picker.pick("grep", { scope = "package" }) end, { desc = "Grep (package)" })
  map("n", "<leader>/",  function() Snacks.picker.pick("grep", { scope = "root" }) end, { desc = "Grep (root)" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader><space>", function() Snacks.picker.pick("switch", { scope = "workspace" }) end, { desc = "Switch (workspace)" })
  map("n", "<leader>R",       function() Snacks.picker.pick("switch", { scope = "root" }) end, { desc = "Switch (root)" })
  map("n", "<leader>r",       function() Snacks.picker.pick("switch", { scope = "cwd" }) end, { desc = "Switch (cwd)" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>fd", function() Snacks.picker.pick("directories") end, { desc = "Find Directory" })
  map("n", "<leader>fn", function() Snacks.picker.pick("node_modules") end, { desc = "Find Package (node_modules)" })
  map("n", "<leader>fp", function() Snacks.picker.pick("packages") end, { desc = "Find Package" })
  map("n", "<leader>fP", function() Snacks.picker.pick("plugins") end, { desc = "Find Plugin (lazy)" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>'", function() Snacks.picker.pick("recall") end, { desc = "Recall" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>,", function() Snacks.picker.buffers() end, { desc = "Buffers" })
  map("n", "<leader>:", function() Snacks.picker.command_history() end, { desc = "Command History" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>sb", function() Snacks.picker.grep_buffers() end, { desc = "Grep Open Buffers" })
  map("n", "<leader>sl", function() Snacks.picker.lines() end, { desc = "Grep Lines" })
  -- stylua: ignore end

  -- stylua: ignore start
  map({ "n", "x" }, "<leader>*", function() Snacks.picker.pick("grep_word") end, { desc = "selection or word" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", '<leader>s"', function() Snacks.picker.registers() end, { desc = "Registers" })
  map("n", '<leader>s/', function() Snacks.picker.search_history() end, { desc = "Search History" })
  map("n", "<leader>sa", function() Snacks.picker.autocmds() end, { desc = "Autocmds" })
  map("n", "<leader>sc", function() Snacks.picker.command_history() end, { desc = "Command History" })
  map("n", "<leader>sC", function() Snacks.picker.commands() end, { desc = "Commands" })
  map("n", "<leader>sd", function() Snacks.picker.diagnostics() end, { desc = "Diagnostics" })
  map("n", "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, { desc = "Buffer Diagnostics" })
  map("n", "<leader>sh", function() Snacks.picker.help() end, { desc = "Help Pages" })
  map("n", "<leader>sH", function() Snacks.picker.highlights() end, { desc = "Highlights" })
  map("n", "<leader>si", function() Snacks.picker.icons() end, { desc = "Icons" })
  map("n", "<leader>sj", function() Snacks.picker.jumps() end, { desc = "Jumps" })
  map("n", "<leader>sk", function() Snacks.picker.keymaps() end, { desc = "Keymaps" })
  map("n", "<leader>sl", function() Snacks.picker.loclist() end, { desc = "Location List" })
  map("n", "<leader>sM", function() Snacks.picker.man() end, { desc = "Man Pages" })
  map("n", "<leader>sm", function() Snacks.picker.marks() end, { desc = "Marks" })
  map("n", "<leader>sR", function() Snacks.picker.resume() end, { desc = "Resume" })
  map("n", "<leader>sq", function() Snacks.picker.qflist() end, { desc = "Quickfix List" })
  map("n", "<leader>su", function() Snacks.picker.undo() end, { desc = "Undotree" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>uC", function() Snacks.picker.colorschemes() end, { desc = "Colorschemes" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>ss", function() Snacks.picker.pick("symbols") end, { desc = "Symbols" })
  -- stylua: ignore end

  -- stylua: ignore start
  map("n", "<leader>gl", function() Snacks.picker.git_log({ cwd = Config.root("git") }) end, { desc = "Git Log" })
  map("n", "<leader>gL", function() Snacks.picker.git_log_file() end, { desc = "Git Log File" })
  map("n", "<leader>gb", function() Snacks.picker.git_log_line() end, { desc = "Git Blame Line" })
  map("n", "<leader>gf", function() Snacks.picker.git_log_file() end, { desc = "Git Current File History" })
  map({ "n", "x" }, "<leader>gO", function() Snacks.gitbrowse() end, { desc = "Git Browse (open)" })
  map({ "n", "x" }, "<leader>gY", function() Snacks.gitbrowse({ open = function(url) vim.fn.setreg("+", url) end, notify = false }) end, { desc = "Git Browse (copy)" })
  -- stylua: ignore end

  return opts
end

return SnacksPickerConfig
