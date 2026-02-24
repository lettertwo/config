---@module "snacks"

return {
  {
    "folke/snacks.nvim",
    init = function()
      vim.api.nvim_create_user_command("LazyGitNeogitCommit", function()
        -- Auto re-enter terminal mode when returning to the lazygit buffer
        local lazygit_buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_create_autocmd("BufEnter", {
          buffer = lazygit_buf,
          once = true,
          callback = function()
            vim.schedule(function()
              vim.cmd("startinsert")
            end)
          end,
        })
        -- Boost neogit popup zindex to show above lazygit
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "NeogitPopup",
          once = true,
          callback = function()
            local win = vim.api.nvim_get_current_win()
            local config = vim.api.nvim_win_get_config(win)
            config.zindex = 200
            vim.api.nvim_win_set_config(win, config)
          end,
        })
        require("neogit").open({ "commit" })
      end, {})
    end,
    opts = {
      ---@type snacks.lazygit.Config
      lazygit = {
        configure = false,
        args = {
          "--use-config-file",
          vim.fs.normalize(vim.fn.stdpath("config") .. "/../lazygit/config.yml") .. "," .. vim.fs.normalize(
            vim.fn.stdpath("config") .. "/../lazygit/config-nvim.yml"
          ),
        },
        win = {
          style = "lazygit",
          zindex = 99,
          backdrop = false,
          width = 0,
          height = 0,
        },
      },
    },
  },
}
