return {
  {
    "ibhagwan/fzf-lua",
    -- keys = function()
    --   return {}
    -- end,
    keys = {
      -- {
      --   "<leader>sP",
      --   require("lazyvim.util").pick("live_grep", { root = false, cwd = vim.fn.stdpath("data") .. "/lazy/" }),
      --   desc = "Grep plugins",
      -- },
    },
    opts = {
      winopts = {
        height = 0.4,
        width = 1,
        row = 1,
        preview = {
          vertical = "up",
          delay = 10,
        },
        -- split = "belowright new",
      },
      files = {
        fzf_opts = {
          ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-files-history",
        },
      },
      grep = {
        fzf_opts = {
          ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-grep-history",
        },
      },
    },
  },
}
