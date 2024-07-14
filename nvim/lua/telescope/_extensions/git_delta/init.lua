return require("telescope").register_extension({
  setup = require("telescope._extensions.git_delta.config"),
  exports = {
    commits = require("telescope._extensions.git_delta.commits"),
    status = require("telescope._extensions.git_delta.status"),
  },
})
