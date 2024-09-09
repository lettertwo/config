local icons = require("config").icons

local printed = false

return {
  {
    "luukvbaal/statuscol.nvim",
    event = "VeryLazy",
    opts = function()
      local builtin = require("statuscol.builtin")
      return {
        separator = " ",
        relculright = true,
        setopt = true,
        ft_ignore = require("config").filetypes.ui,
        segments = {
          -- sign
          { text = { "%s" }, click = "v:lua.ScSa" },
          -- line number
          {
            text = { builtin.lnumfunc, " " },
            condition = { true, builtin.not_empty },
            click = "v:lua.ScLa",
          },
          -- fold
          {
            text = { builtin.foldfunc, " " },
            condition = { true, builtin.not_empty },
            click = "v:lua.ScFa",
          },
        },
      }
    end,
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    cmd = { "ToggleUfo" },
    -- stylua: ignore
    keys = {
      { "zk", function() require('ufo').peekFoldedLinesUnderCursor() end, desc = "Peek folded lines" },
      { "<leader>uu", "<cmd>ToggleUfo<cr>", desc = "Toggle UFO" },
    },
    opts = {
      open_fold_hl_timeout = 0,
      fold_virt_text_handler = function(text, lnum, endLnum, width)
        local suffix = "  "
        local lines = ("(%d lines) "):format(endLnum - lnum)

        local cur_width = 0
        for _, section in ipairs(text) do
          cur_width = cur_width + vim.fn.strdisplaywidth(section[1])
        end

        suffix = suffix .. (" "):rep(width - cur_width - vim.fn.strdisplaywidth(lines) - 3)

        table.insert(text, { suffix, "Comment" })
        table.insert(text, { lines, "Todo" })
        return text
      end,
    },
    config = function(_, opts)
      require("ufo").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = require("config").filetypes.ui,
        callback = function()
          pcall(require("ufo").detach)
        end,
      })

      local toggle_ufo = require("util").create_toggle("ufo", "b", function(value)
        if value then
          require("ufo").attach()
        else
          require("ufo").detach()
        end
      end)

      vim.api.nvim_create_user_command("ToggleUfo", toggle_ufo, {})
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPost",
    opts = {
      signs = {
        add = { text = "▌" },
        change = { text = "▌" },
        topdelete = { text = "▔" },
        delete = { text = "▁" },
        changedelete = { text = "▌" },
        untracked = { text = "▌" },
      },
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
        local gitsigns = require("gitsigns")

        vim.keymap.set({ "x", "o" }, "ih", gitsigns.select_hunk, { buffer = buffer, desc = "Select hunk" })
        vim.keymap.set({ "x", "o" }, "ah", gitsigns.select_hunk, { buffer = buffer, desc = "Select hunk" })

        vim.keymap.set({ "x", "n" }, "<leader>ga", gitsigns.stage_hunk, { buffer = buffer, desc = "Stage hunk" })
        vim.keymap.set({ "x", "n" }, "<leader>gr", gitsigns.reset_hunk, { buffer = buffer, desc = "Reset hunk" })

        vim.keymap.set("n", "<leader>gj", gitsigns.next_hunk, { buffer = buffer, desc = "Next Hunk" })
        vim.keymap.set("n", "<leader>gk", gitsigns.prev_hunk, { buffer = buffer, desc = "Prev Hunk" })
        vim.keymap.set("n", "<leader>gA", gitsigns.stage_buffer, { buffer = buffer, desc = "Stage buffer" })
        vim.keymap.set("n", "<leader>gu", gitsigns.undo_stage_hunk, { buffer = buffer, desc = "Unstage hunk" })
        vim.keymap.set("n", "<leader>gR", gitsigns.reset_buffer, { buffer = buffer, desc = "Reset buffer" })
        vim.keymap.set("n", "<leader>gp", gitsigns.preview_hunk, { buffer = buffer, desc = "Preview hunk" })
        vim.keymap.set("n", "<leader>gb", function()
          gitsigns.blame_line({ full = true })
        end, { buffer = buffer, desc = "Blame" })
        vim.keymap.set("n", "<leader>gD", gitsigns.toggle_deleted, { buffer = buffer, desc = "Toggle deleted lines" })
        vim.keymap.set(
          "n",
          "<leader>uD",
          "<leader>gD",
          { remap = true, buffer = buffer, desc = "Toggle deleted lines" }
        )
        vim.keymap.set(
          "n",
          "<leader>uB",
          gitsigns.toggle_current_line_blame,
          { buffer = buffer, desc = "Toggle line blame" }
        )

        vim.keymap.set("n", "]c", function()
          if vim.wo.diff then
            return "]c"
          end
          vim.schedule(function()
            gitsigns.next_hunk()
          end)
          return "<Ignore>"
        end, { buffer = buffer, desc = "Next hunk" })

        vim.keymap.set("n", "[c", function()
          if vim.wo.diff then
            return "[c"
          end
          vim.schedule(function()
            gitsigns.prev_hunk()
          end)
          return "<Ignore>"
        end, { buffer = buffer, desc = "Previous hunk" })
      end,
    },
  },
}
