return {
  {
    "lewis6991/gitsigns.nvim",
    event = "LazyFile",
    -- enabled = true,
    opts = {
      -- signs = {
      --   add = { text = "▌" },
      --   change = { text = "▌" },
      --   topdelete = { text = "▔" },
      --   delete = { text = "▁" },
      --   changedelete = { text = "▌" },
      --   untracked = { text = "▌" },
      -- },
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
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        local function next_hunk()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end

        local function prev_hunk()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end

        -- navigation
        map("n", "<leader>gj", next_hunk, "Next Hunk")
        map("n", "]h", next_hunk, "Next Hunk")
        map("n", "<leader>gk", prev_hunk, "Prev Hunk")
        map("n", "[h", prev_hunk, "Prev Hunk")
        map("n", "]H", function()
          gs.nav_hunk("last")
        end, "Last Hunk")
        map("n", "[H", function()
          gs.nav_hunk("first")
        end, "First Hunk")

        -- status
        map({ "x", "n" }, "<leader>ga", gs.stage_hunk, "Stage hunk")
        map({ "x", "n" }, "<leader>gr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>gA", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>gu", gs.undo_stage_hunk, "Unstage hunk")
        map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")

        -- preview
        map("n", "<leader>gp", gs.preview_hunk_inline, "Preview hunk")

        -- toggles
        map("n", "<leader>gD", gs.toggle_deleted, "Toggle deleted lines")
        map("n", "<leader>uD", gs.toggle_deleted, "Toggle deleted lines")
        map("n", "<leader>uB", gs.toggle_current_line_blame, "Toggle line blame")

        -- selection
        map({ "x", "o" }, "ih", gs.select_hunk, "Select hunk")
        map({ "x", "o" }, "ah", gs.select_hunk, "Select hunk")

        -- blame
        map("n", "<leader>gb", function()
          gs.blame_line({ full = true })
        end, "Blame")
        map("n", "<leader>gB", function()
          gs.blame()
        end, "Blame Buffer")

        -- diff
        -- map("n", "<leader>gd", gs.diffthis, "Diff This")
        -- map("n", "<leader>gD", function()
        --   gs.diffthis("~")
        -- end, "Diff This ~")
      end,
    },
  },
}
