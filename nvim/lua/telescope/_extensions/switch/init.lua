return require("telescope").register_extension({
  setup = require("telescope._extensions.switch.config"),
  exports = {
    switch = require("telescope._extensions.switch.switch"),
  },
})
