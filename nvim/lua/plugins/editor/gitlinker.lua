return {
  {
    "ruifm/gitlinker.nvim",
    keys = {
      {
        "gb",
        function()
          require("gitlinker").get_buf_range_url(
            "n",
            { action_callback = require("gitlinker.actions").open_in_browser }
          )
        end,
        mode = { "n" },
        desc = "Open in browser",
      },
      {
        "gb",
        function()
          require("gitlinker").get_buf_range_url(
            "n",
            { action_callback = require("gitlinker.actions").open_in_browser }
          )
        end,
        mode = { "v" },
        desc = "Open in browser",
      },
    },
    opts = {
      mappings = nil,
      callbacks = {
        ["stash.atlassian.com"] = function(url_data)
          local host = url_data.host
          local project, repo = unpack(vim.split(url_data.repo, "/"))
          local file = url_data.file
          local rev = url_data.rev
          local loc = url_data.lstart
          if url_data.lend then
            loc = loc .. "-" .. url_data.lend
          end

          return string.format(
            "https://%s/projects/%s/repos/%s/browse/%s?at=%s#%s",
            host,
            project,
            repo,
            file,
            rev,
            loc
          )
        end,
      },
    },
  },
}
