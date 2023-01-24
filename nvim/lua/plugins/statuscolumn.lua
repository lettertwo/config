local icons = require("config").icons

return {
  {
    "luukvbaal/statuscol.nvim",
    event = "VeryLazy",
    opts = {
      separator = " ",
      relculright = true,
      setopt = false,
      order = "SsNsFs",

      foldfunc = function()
        if vim.v.wrap then
          return ""
        end

        local lnum = vim.v.lnum
        local icon = icons.fold.fold

        -- Line isn't in folding range
        if vim.fn.foldlevel(lnum) <= 0 then
          return icon
        end

        -- Not the first line of folding range
        if vim.fn.foldlevel(lnum) <= vim.fn.foldlevel(lnum - 1) then
          return icon
        end

        if vim.fn.foldclosed(lnum) == -1 then
          icon = icons.fold.foldclose
        else
          icon = icons.fold.foldopen
        end

        return icon
      end,

      FoldToggle = function(args)
        vim.notify("toggling fold on line " .. args.mousepos.line)
      end,
    },
    config = function(_, opts)
      require("statuscol").setup(opts)
      local reeval = opts.reeval or opts.relculright
      local stc = ""

      _G.ScFi = opts.foldfunc
      -- TODO: make this work
      _G.ScFa = opts.FoldToggle

      for i = 1, #opts.order do
        local segment = opts.order:sub(i, i)
        if segment == "F" then
          stc = stc .. "%@v:lua.ScFa@"
          stc = stc .. "%{%v:lua.ScFi()%}"
          -- End the click execute label if separator is not next
          if opts.order:sub(i + 1, i + 1) ~= "s" then
            stc = stc .. "%T"
          end
        elseif segment == "S" then
          stc = stc .. "%@v:lua.ScSa@%s%T"
        elseif segment == "N" then
          stc = stc .. "%@v:lua.ScLa@"
          stc = stc .. (reeval and "%=%{v:lua.ScLn()}" or "%{%v:lua.ScLn()%}")
          -- End the click execute label if separator is not next
          if opts.order:sub(i + 1, i + 1) ~= "s" then
            stc = stc .. "%T"
          end
        elseif segment == "s" then
          -- Add click execute label if line number was not previous
          if opts.order:sub(i - 1, i - 1) == "N" then
            stc = stc .. "%{v:lua.ScSp()}%T"
          else
            stc = stc .. "%@v:lua.ScLa@%{v:lua.ScSp()}%T"
          end
        end
      end

      vim.opt.statuscolumn = stc
      vim.api.nvim_create_autocmd("FileType", {
        pattern = require("config").filetypes.ui,
        -- stylua: ignore
        callback = function() vim.opt.statuscolumn = "" end,
      })
    end,
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    -- stylua: ignore
    keys = {
      { "zR", function() require("ufo").openAllFolds() end, desc = "Open all folds" },
      { "zM", function() require("ufo").closeAllFolds() end, desc = "Close all folds" },
      { "zr", function() require("ufo").openFoldsExceptKinds() end, desc = "Open fold" },
      { "zm", function() require("ufo").closeFoldsWith() end, desc = "Close fold" },
      { "zk", function() require('ufo').peekFoldedLinesUnderCursor() end, desc = "Peek folded lines" },
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
        callback = require("ufo").detach,
      })
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
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
        vim.keymap.set("n", "<leader>gl", function()
          gitsigns.blame_line({ full = true })
        end, { buffer = buffer, desc = "Blame" })
        vim.keymap.set("n", "<leader>gd", gitsigns.diffthis, { buffer = buffer, desc = "Diff" })
        vim.keymap.set("n", "<leader>gD", function()
          gitsigns.diffthis("~")
        end, { buffer = buffer, desc = "Diff this file" })
        vim.keymap.set("n", "<leader>gt", gitsigns.toggle_deleted, { buffer = buffer, desc = "Toggle deleted files" })

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