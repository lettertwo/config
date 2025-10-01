return {
  {
    "folke/sidekick.nvim",
    ---@module "sidekick"
    ---@type sidekick.Config
    opts = {
      cli = {
        win = {
          -- stylua: ignore
          keys = {
            hide_n = false,
            hide_t = false,
            win_p = false,
            blur = false,
            hide = { "<c-q>", mode = { "t", "n" } },
            move_left = { "<c-h>", function() vim.cmd.wincmd("h"); vim.cmd.stopinsert() end },
            move_down = { "<c-j>", function() vim.cmd.wincmd("j"); vim.cmd.stopinsert() end },
            move_up = { "<c-k>", function() vim.cmd.wincmd("k"); vim.cmd.stopinsert() end },
            move_right = { "<c-l>", function() vim.cmd.wincmd("l"); vim.cmd.stopinsert() end },
            new_line = { "<s-cr>", function(t) t:send("\\" ); t:submit() end, mode = "t" },
          },
        },
      },
    },
  },
}
