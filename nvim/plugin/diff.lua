local map = vim.keymap.set

---@class QueueItem
---@field op fun(): nil
---@field args { n: integer }

-- A simple queue to serialize gitsigns operations,
-- preventing errors when multiple operations are triggered in quick succession.
---@type {[1]: fun(): nil}[]
local queue = {}

local function dequeue()
  local item = table.remove(queue, 1)
  if item then
    local args = item.args or { n = 0 }
    table.insert(args, args.n + 1, function(err)
      if err then
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
      end
      dequeue()
    end)
    args.n = args.n + 1
    item.op(unpack(item.args, 1, item.args.n))
  end
end

---@param op fun(): nil
---@param ... any Arguments to pass to the operation, excluding the callback
local function enqueue(op, ...)
  table.insert(queue, { op = op, args = { n = select("#", ...), ... } })
  if #queue == 1 then
    dequeue()
  end
end

local function setup()
  Config.add("MunifTanjim/nui.nvim")
  Config.add("lewis6991/gitsigns.nvim")
  Config.add("esmuellert/codediff.nvim")

  ---@module "gitsigns"
  ---@type gitsigns.main
  local gs = require("gitsigns")

  gs.setup({
    numhl = true,
    -- linehl = true,
    sign_priority = 6,
    current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
      delay = 500,
      ignore_whitespace = false,
    },
    current_line_blame_formatter = " <author> • <author_time:%m/%d/%y %I:%M %p> • <summary>",
    preview_config = {
      border = "rounded",
      style = "minimal",
      relative = "cursor",
      row = 0,
      col = 1,
    },
    on_attach = function(buffer)
      local function next_hunk()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          enqueue(gs.nav_hunk, "next", nil)
        end
      end

      local function prev_hunk()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          enqueue(gs.nav_hunk, "prev", nil)
        end
      end

      local function toggle_hunk()
        local mode = vim.api.nvim_get_mode().mode
        if mode == "v" or mode == "V" then
          enqueue(gs.stage_hunk, { vim.fn.line("."), vim.fn.line("v") }, nil)
        else
          enqueue(gs.stage_hunk, nil, nil)
        end
      end

      local function toggle_buffer()
        enqueue(gs.stage_buffer)
      end

      local function preview_hunk_inline()
        enqueue(gs.preview_hunk_inline)
      end

      local function reset_hunk()
        local mode = vim.api.nvim_get_mode().mode
        if mode == "v" or mode == "V" then
          enqueue(gs.reset_hunk, { vim.fn.line("."), vim.fn.line("v") }, nil)
        else
          enqueue(gs.reset_hunk, nil, nil)
        end
      end

      local function bufmap(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
      end

      -- navigation
      bufmap("n", "<leader>gj", next_hunk, "Next Hunk")
      bufmap("n", "]h", next_hunk, "Next Hunk")
      bufmap("n", "<leader>gk", prev_hunk, "Prev Hunk")
      bufmap("n", "[h", prev_hunk, "Prev Hunk")

      -- status
      bufmap({ "x", "n" }, "<leader>ga", toggle_hunk, "Toggle hunk")
      bufmap({ "x", "n" }, "<leader>gr", reset_hunk, "Reset hunk")
      bufmap("n", "<leader>gA", toggle_buffer, "Toggle staged buffer")
      bufmap("n", "<leader>gR", gs.reset_buffer, "Reset buffer")

      -- preview
      bufmap("n", "<leader>gp", preview_hunk_inline, "Preview hunk")

      -- toggles
      bufmap("n", "<leader>uB", gs.toggle_current_line_blame, "Toggle line blame")

      -- selection
      bufmap({ "x", "o" }, "ih", gs.select_hunk, "Select hunk")
      bufmap({ "x", "o" }, "ah", gs.select_hunk, "Select hunk")

      -- blame
      bufmap("n", "<leader>gb", function()
        enqueue(gs.blame, {})
      end, "Blame")
    end,
  })

  local CodeDiff = require("codediff")

  CodeDiff.setup({
    keymaps = {
      view = {
        toggle_explorer = "<leader>E", -- Toggle explorer visibility (explorer mode only)
        -- next_hunk = "]c", -- Jump to next change
        -- prev_hunk = "[c", -- Jump to previous change
        -- next_file = "]f", -- Next file in explorer/history mode
        -- prev_file = "[f", -- Previous file in explorer/history mode
        -- diff_get = "do", -- Get change from other buffer (like vimdiff)
        -- diff_put = "dp", -- Put change to other buffer (like vimdiff)
        -- open_in_prev_tab = "gf", -- Open current buffer in previous tab (or create one before)
        -- toggle_stage = "-", -- Stage/unstage current file (works in explorer and diff buffers)
        -- stage_hunk = "<leader>hs", -- Stage hunk under cursor to git index
        -- unstage_hunk = "<leader>hu", -- Unstage hunk under cursor from git index
        -- discard_hunk = "<leader>hr", -- Discard hunk under cursor (working tree only)
        -- show_help = "g?", -- Show floating window with available keymaps
      },
      -- explorer = {
      --   select = "<CR>", -- Open diff for selected file
      --   hover = "K", -- Show file diff preview
      --   refresh = "R", -- Refresh git status
      --   toggle_view_mode = "i", -- Toggle between 'list' and 'tree' views
      --   stage_all = "S", -- Stage all files
      --   unstage_all = "U", -- Unstage all files
      --   restore = "X", -- Discard changes (restore file)
      -- },

      -- view = {
      --   quit = "q",                    -- Close diff tab
      --   toggle_explorer = "<leader>b",  -- Toggle explorer visibility (explorer mode only)
      --   focus_explorer = "<leader>e",   -- Focus explorer panel (explorer mode only)
      --   next_hunk = "]c",   -- Jump to next change
      --   prev_hunk = "[c",   -- Jump to previous change
      --   next_file = "]f",   -- Next file in explorer/history mode
      --   prev_file = "[f",   -- Previous file in explorer/history mode
      --   diff_get = "do",    -- Get change from other buffer (like vimdiff)
      --   diff_put = "dp",    -- Put change to other buffer (like vimdiff)
      --   open_in_prev_tab = "gf", -- Open current buffer in previous tab (or create one before)
      --   close_on_open_in_prev_tab = false, -- Close codediff tab after gf opens file in previous tab
      --   toggle_stage = "-", -- Stage/unstage current file (works in explorer and diff buffers)
      --   stage_hunk = "<leader>hs",   -- Stage hunk under cursor to git index
      --   unstage_hunk = "<leader>hu", -- Unstage hunk under cursor from git index
      --   discard_hunk = "<leader>hr", -- Discard hunk under cursor (working tree only)
      --   hunk_textobject = "ih",      -- Textobject for hunk (vih to select, yih to yank, etc.)
      --   show_help = "g?",   -- Show floating window with available keymaps
      --   align_move = "gm", -- Temporarily align moved code blocks across panes
      --   toggle_layout = "t", -- Toggle between side-by-side and inline layout
      -- },
      -- explorer = {
      --   select = "<CR>",    -- Open diff for selected file
      --   hover = "K",        -- Show file diff preview
      --   refresh = "R",      -- Refresh git status
      --   toggle_view_mode = "i",  -- Toggle between 'list' and 'tree' views
      --   stage_all = "S",    -- Stage all files
      --   unstage_all = "U",  -- Unstage all files
      --   restore = "X",      -- Discard changes (restore file)
      --   toggle_changes = "gu",  -- Toggle Changes (unstaged) group visibility
      --   toggle_staged = "gs",   -- Toggle Staged Changes group visibility
      --   -- Fold keymaps (Vim-style)
      --   fold_open = "zo",           -- Open fold (expand current node)
      --   fold_open_recursive = "zO", -- Open fold recursively (expand all descendants)
      --   fold_close = "zc",          -- Close fold (collapse current node)
      --   fold_close_recursive = "zC", -- Close fold recursively (collapse all descendants)
      --   fold_toggle = "za",         -- Toggle fold (expand/collapse current node)
      --   fold_toggle_recursive = "zA", -- Toggle fold recursively
      --   fold_open_all = "zR",       -- Open all folds in tree
      --   fold_close_all = "zM",      -- Close all folds in tree
      -- },
      -- history = {
      --   select = "<CR>",    -- Select commit/file or toggle expand
      --   toggle_view_mode = "i",  -- Toggle between 'list' and 'tree' views
      --   refresh = "R",      -- Refresh history (re-fetch commits)
      --   -- Fold keymaps (Vim-style, apply to directory nodes only)
      --   fold_open = "zo",           -- Open fold (expand current node)
      --   fold_open_recursive = "zO", -- Open fold recursively (expand all descendants)
      --   fold_close = "zc",          -- Close fold (collapse current node)
      --   fold_close_recursive = "zC", -- Close fold recursively (collapse all descendants)
      --   fold_toggle = "za",         -- Toggle fold (expand/collapse current node)
      --   fold_toggle_recursive = "zA", -- Toggle fold recursively
      --   fold_open_all = "zR",       -- Open all folds in tree
      --   fold_close_all = "zM",      -- Close all folds in tree
      -- },
      -- conflict = {
      --   accept_incoming = "<leader>ct",  -- Accept incoming (theirs/left) change
      --   accept_current = "<leader>co",   -- Accept current (ours/right) change
      --   accept_both = "<leader>cb",      -- Accept both changes (incoming first)
      --   discard = "<leader>cx",          -- Discard both, keep base
      --   -- Accept all (whole file) - uppercase versions
      --   accept_all_incoming = "<leader>cT",  -- Accept ALL incoming changes
      --   accept_all_current = "<leader>cO",   -- Accept ALL current changes
      --   accept_all_both = "<leader>cB",      -- Accept ALL both changes
      --   discard_all = "<leader>cX",          -- Discard ALL, reset to base
      --   next_conflict = "]x",            -- Jump to next conflict
      --   prev_conflict = "[x",            -- Jump to previous conflict
      --   diffget_incoming = "2do",        -- Get hunk from incoming (left/theirs) buffer
      --   diffget_current = "3do",         -- Get hunk from current (right/ours) buffer
      -- },
    },
    diff = {
      -- layout = "inline",
      conflict_result_position = "center",
      compute_moves = true,
    },
    explorer = {
      focus_on_select = true,
    },
  })

  map("n", "<leader>go", "<cmd>CodeDiff --inline file HEAD<cr>", { desc = "Overlay file diff" })
  map("n", "<leader>gd", "<cmd>CodeDiff HEAD<cr>", { desc = "Show diff" })
  map("n", "<leader>gl", "<cmd>CodeDiff history<cr>", { desc = "Show history (log)" })
  map("n", "<leader>gL", "<cmd>CodeDiff history %<cr>", { desc = "Show file history (log)" })
  map("n", "<leader>gb", "<cmd>.,.CodeDiff history<cr>", { desc = "Show line history (blame)" })

  map("x", "<leader>gl", ":CodeDiff history<cr>", { desc = "Show line history (blame)" })
  map("x", "<leader>gb", "<leader>gl", { remap = true, desc = "Show line history (blame)" })

  local lifecycle = require("codediff.ui.lifecycle")

  Config.on("FileType", { "codediff-explorer", "codediff-history" }, function(event)
    local buf = event.buf

    Config.on("CursorHold", buf, function()
      local panel = lifecycle.get_explorer(vim.api.nvim_get_current_tabpage())
      if not panel or panel.bufnr ~= buf or not panel.tree then
        return
      end

      local node = panel.tree:get_node()
      local data = node and node.data or nil
      local type = data and data.type or nil

      if type == nil then
        if data and data.path and vim.fn.isdirectory(data.path) ~= 1 then
          type = "file"
        end
      end

      if data == nil or type ~= "file" then
        return
      end

      panel.on_file_select(data, { no_jump = true })
    end)
  end)
end

if vim.g.mergetool == true then
  setup()
else
  vim.schedule(setup)
end
