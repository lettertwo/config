local gitsigns = require("gitsigns")

gitsigns.setup({
  current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
    delay = 500,
    ignore_whitespace = false,
  },
  current_line_blame_formatter = ' <author> • <author_time:%m/%d/%y %I:%M %p> • <summary>',
  preview_config = {
    border = "rounded",
    style = "minimal",
    relative = "cursor",
    row = 0,
    col = 1,
  },
  on_attach = function(bufnr)
    print("GitSigns: attached to buffer " .. bufnr)
    local keymap = require("keymap").buffer(bufnr)

    keymap.normal.leader({
      g = {
        name = "Git",
        s = { gitsigns.stage_hunk, "Stage hunk" },
        S = { gitsigns.stage_buffer, "Stage buffer" },
        u = { gitsigns.undo_stage_hunk, "Unstage hunk" },
        r = { gitsigns.reset_hunk, "Reset hunk" },
        R = { gitsigns.reset_buffer, "Reset buffer" },
        p = { gitsigns.preview_hunk, "Preview hunk" },
        b = { function() gitsigns.blame_line({full=true}) end, "Blame" },
        d = { gitsigns.diffthis, "Diff" },
        D = { function() gitsigns.diffthis('~') end, "Diff this file" },
        t = { gitsigns.toggle_deleted, "Toggle deleted lines" },
      },
    })

    keymap.operator("ih", gitsigns.select_hunk, "Select hunk")
    keymap.operator("ah", gitsigns.select_hunk, "Select hunk")

    keymap.normal("]c", function()
      if vim.wo.diff then return ']c' end
      vim.schedule(function() gitsigns.next_hunk() end)
      return '<Ignore>'
    end, "Next hunk")

    keymap.normal("[c", function()
      if vim.wo.diff then return '[c' end
      vim.schedule(function() gitsigns.prev_hunk() end)
      return '<Ignore>'
    end, "Previous hunk")

  end
})
