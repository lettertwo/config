return {
  {
    "fnune/recall.nvim",
    dependencies = { "folke/snacks.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    cmd = {
      -- wrapped
      "RecallMark",
      "RecallUnmark",
      "RecallToggle",
      "RecallNext",
      "RecallPrevious",
      "RecallClear",

      -- custom
      "RecallNextBuffer",
      "RecallPreviousBuffer",
      "RecallClearBuffer",
      "RecallToggleBuffer",
      "RecallCloseUnmarkedBuffers",
      "RecallDeleteAndUnmarkBuffer",
      "RecallDeleteAndUnmarkOthers",
    },
    keys = {
      { "<leader>m", "<cmd>RecallToggleBuffer<cr>", desc = "Toggle mark" },
      { "<leader>M", "<cmd>RecallClearBuffer<cr>", desc = "Clear buffer marks" },
      { "<C-m>", "<cmd>RecallToggle<cr>", desc = "Toggle mark" },
      { "<s-l>", "<cmd>RecallNextBuffer<cr>", desc = "Next marked buffer" },
      { "<s-h>", "<cmd>RecallPreviousBuffer<cr>", desc = "Previous marked buffer" },
      { "<leader>bc", "<cmd>RecallCloseUnmarkedBuffers<cr>", desc = "Close unmarked buffers" },
      { "<leader>bm", "<cmd>RecallClearBuffer<cr>", desc = "Clear buffer marks" },
      { "<leader>bM", "<cmd>RecallClear<cr>", desc = "Clear all marks" },
      { "<leader>bd", "<cmd>RecallDeleteAndUnmarkBuffer<cr>", desc = "Delete and unmark buffer" },
      { "<leader>bo", "<cmd>RecallDeleteAndUnmarkOthers<cr>", desc = "Delete and unmark others" },
    },
    config = function(_, opts)
      require("recall").setup(vim.tbl_deep_extend("force", {}, opts or {}, {
        sign = LazyVim.config.icons.tag,
        sign_highlight = "@tag",
      }))

      local recall_util = require("util.recall")

      -- Wrapped Commands
      -- stylua: ignore start
      vim.api.nvim_create_user_command("RecallMark",     function() recall_util.mark() end, {})
      vim.api.nvim_create_user_command("RecallUnmark",   function() recall_util.unmark() end, {})
      vim.api.nvim_create_user_command("RecallToggle",   function() recall_util.toggle() end, {})
      vim.api.nvim_create_user_command("RecallNext",     function() recall_util.goto_next() end, {})
      vim.api.nvim_create_user_command("RecallPrevious", function() recall_util.goto_prev() end, {})
      vim.api.nvim_create_user_command("RecallClear",    function() recall_util.clear() end, {})
      -- stylua: ignore end

      vim.api.nvim_create_user_command("RecallNextBuffer", function()
        local current_file = recall_util.normalize_filepath(0)
        local marked_files = recall_util.iter_marked_files()
        local next_file = marked_files:next()
        local saw_current_file = next_file == current_file
        next_file = marked_files:find(function(file)
          if saw_current_file then
            return true
          elseif file == current_file then
            saw_current_file = true
          end
        end) or next_file
        if next_file then
          vim.cmd.edit(next_file)
        else
          vim.notify("No marked buffers found", vim.log.levels.WARN)
        end
      end, {})

      vim.api.nvim_create_user_command("RecallPreviousBuffer", function()
        local current_file = recall_util.normalize_filepath(0)
        local marked_files = recall_util.iter_marked_files():rev()
        local prev_file = marked_files:next()
        local saw_current_file = prev_file == current_file
        prev_file = marked_files:find(function(file)
          if saw_current_file then
            return true
          elseif file == current_file then
            saw_current_file = true
          end
        end) or prev_file
        if prev_file then
          vim.cmd.edit(prev_file)
        else
          vim.notify("No marked buffers found", vim.log.levels.WARN)
        end
      end, {})

      vim.api.nvim_create_user_command("RecallClearBuffer", function()
        recall_util.unmark(0)
      end, {})

      vim.api.nvim_create_user_command("RecallToggleBuffer", function()
        recall_util.toggle(0)
      end, {})

      ---Close all buffers that don't have marks
      vim.api.nvim_create_user_command("RecallCloseUnmarkedBuffers", function()
        local marks = recall_util.get_all_marks()
        if not marks or #marks == 0 then
          vim.notify("No marks found", vim.log.levels.WARN)
          return
        end

        local marked_paths = {}
        for _, mark in ipairs(marks) do
          marked_paths[mark.file] = true
        end

        Snacks.bufdelete.delete({
          filter = function(bufnr)
            local should_close = vim.api.nvim_buf_is_valid(bufnr)
              and vim.fn.buflisted(bufnr) >= 1
              and marked_paths[vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))] == nil
            if should_close then
              vim.print("Closing buffer: " .. vim.api.nvim_buf_get_name(bufnr))
            end
            return should_close
          end,
        })
      end, {})

      -- Command: Delete buffer and remove its mark
      vim.api.nvim_create_user_command("RecallDeleteAndUnmarkBuffer", function()
        recall_util.unmark()
        Snacks.bufdelete.delete()
      end, {})

      -- Command: Delete all other buffers and remove their marks
      vim.api.nvim_create_user_command("RecallDeleteAndUnmarkOthers", function()
        Snacks.bufdelete.delete({
          filter = function(b)
            if b == vim.api.nvim_get_current_buf() then
              return false
            end

            if recall_util.has_marks(b) then
              -- Switch to buffer to unmark it
              local current_buf = vim.api.nvim_get_current_buf()
              vim.api.nvim_set_current_buf(b)
              recall_util.unmark()
              vim.api.nvim_set_current_buf(current_buf)
            end

            return true
          end,
        })
      end, {})

      vim.api.nvim_create_autocmd("User", {
        pattern = "RecallUpdate",
        callback = function()
          vim.schedule(vim.cmd.redraw)
        end,
      })
    end,
  },
}
