return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>go",
        function()
          Snacks.gitbrowse()
        end,
        mode = { "n", "x" },
        desc = "Git Browse (open)",
      },
    },
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      gitbrowse = {
        urlpatterns = {
          -- FIXME: Figure out why this override isn't working.
          -- it's meant to fix the bad range formatting in the default config.
          ["bitbucket%.org"] = {
            branch = "/src/{branch}",
            file = "/src/{branch}/{file}#lines-{line_start}:{line_end}",
            permalink = "/src/{commit}/{file}#lines-{line_start}:{line_end}",
            commit = "/commits/{commit}",
          },
        },
      },
    },
  },
}
