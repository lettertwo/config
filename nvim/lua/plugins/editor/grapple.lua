return {
  {
    "cbochs/grapple.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "Grapple", "CloseUntaggedBuffers", "ToggledTaggedBuffer", "NextTaggedBuffer", "PreviousTaggedBuffer" },
    keys = {
      { "<leader>m", "<cmd>ToggleTaggedBuffer<cr>", desc = "Toggle Buffer Tag" },
      { "<s-l>", "<cmd>NextTaggedBuffer<cr>", desc = "Next tag" },
      { "<s-h>", "<cmd>PreviousTaggedBuffer<cr>", desc = "Previous tag" },
      { "<leader>bc", "<cmd>CloseUntaggedBuffers<cr>", desc = "Close untagged buffers" },
    },
    opts = {
      scope = "git_branch", -- also try out "git_branch"
      style = "basename",
    },
    config = function(_, opts)
      require("grapple").setup(opts)

      -- TODO: Figure out why this is not working; it seems to just nuke the contents of open buffers?
      local function close_untagged_buffers()
        local tags = require("grapple").tags()
        if not tags or #tags == 0 then
          vim.notify("No tags found", vim.log.levels.WARN)
        end
        local bufnrs = vim.api.nvim_list_bufs()
        for _, bufnr in ipairs(bufnrs) do
          local should_close = true
          local bufpath = vim.api.nvim_buf_get_name(bufnr)
          for _, tag in ipairs(tags) do
            if tag.path == bufpath then
              should_close = false
              break
            end
          end
          if should_close then
            vim.notify("would close " .. bufnr .. " " .. bufpath, vim.log.levels.INFO)
            -- Util.delete_buffer(bufnr)
          end
        end
      end

      local function is_ui_buffer(bufnr)
        if not bufnr or bufnr == 0 then
          bufnr = vim.api.nvim_get_current_buf()
        end
        local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
        return vim.tbl_contains(require("lazyvim.config").filetypes.ui, ft)
      end

      vim.api.nvim_create_user_command("CloseUntaggedBuffers", close_untagged_buffers, {})

      vim.api.nvim_create_user_command("ToggleTaggedBuffer", function()
        if is_ui_buffer() then
          vim.notify("Cannot tag a UI buffer", vim.log.levels.WARN)
        else
          require("grapple").toggle()
        end
      end, {})

      vim.api.nvim_create_user_command("NextTaggedBuffer", function()
        if is_ui_buffer() then
          -- TODO: check for another window with a non-ui buffer and cycle there?
          vim.notify("Cannot cycle tags in UI buffer", vim.log.levels.WARN)
        else
          require("grapple").cycle_tags("next")
        end
      end, {})

      vim.api.nvim_create_user_command("PreviousTaggedBuffer", function()
        if is_ui_buffer() then
          -- TODO: check for another window with a non-ui buffer and cycle there?
          vim.notify("Cannot cycle tags in UI buffer", vim.log.levels.WARN)
        else
          require("grapple").cycle_tags("prev")
        end
      end, {})
    end,
  },
}
