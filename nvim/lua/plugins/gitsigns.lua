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

return {
  {
    "lewis6991/gitsigns.nvim",
    event = "LazyFile",
    -- enabled = true,
    opts = {
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
        ---@module "gitsigns"
        ---@type gitsigns.main
        local gs = package.loaded.gitsigns

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

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        -- navigation
        map("n", "<leader>gj", next_hunk, "Next Hunk")
        map("n", "]h", next_hunk, "Next Hunk")
        map("n", "<leader>gk", prev_hunk, "Prev Hunk")
        map("n", "[h", prev_hunk, "Prev Hunk")

        -- status
        map({ "x", "n" }, "<leader>ga", toggle_hunk, "Toggle hunk")
        map({ "x", "n" }, "<leader>gr", reset_hunk, "Reset hunk")
        map("n", "<leader>gA", toggle_buffer, "Toggle staged buffer")
        map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")

        -- preview
        map("n", "<leader>gp", preview_hunk_inline, "Preview hunk")

        -- toggles
        map("n", "<leader>uB", gs.toggle_current_line_blame, "Toggle line blame")

        -- selection
        map({ "x", "o" }, "ih", gs.select_hunk, "Select hunk")
        map({ "x", "o" }, "ah", gs.select_hunk, "Select hunk")

        -- blame
        -- map("n", "<leader>gb", function()
        --   gs.blame_line()
        -- end, "Blame")
        map("n", "<leader>gb", function()
          enqueue(gs.blame, {})
        end, "Blame")

        -- diff
        map("n", "<leader>gd", gs.diffthis, "Diff This")
        map("n", "<leader>gD", function()
          gs.diffthis("~")
        end, "Diff This ~")
      end,
    },
  },
}
