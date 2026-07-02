-- snacks provides the outline sidebar's picker. The default app also adds it
-- with a full config; snacks.setup() is idempotent (first caller wins), so in
-- embedded review this is a no-op and standalone gets the minimal picker init.
Config.add("folke/snacks.nvim")
require("snacks").setup({ picker = { enabled = true } })
