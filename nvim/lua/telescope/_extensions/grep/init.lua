return require("telescope").register_extension({
  setup = require("telescope._extensions.grep.config"),
  exports = {
    grep = require("telescope._extensions.grep.grep").grep,
    relative = require("telescope._extensions.grep.grep").relative,
    open = require("telescope._extensions.grep.grep").open,
  },
})
