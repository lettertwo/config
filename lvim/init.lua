if vim.env.PROF then
  -- Stop profiler on this event. Defaults to `VimEnter`
  -- Stop on a different event by setting `PROF` env var to the event name.
  ---@type "VimEnter" | "UIEnter" | "VeryLazy"
  local event = "VimEnter"
  if #vim.env.PROF > 1 and vim.env.PROF ~= "true" then
    event = vim.env.PROF
  end

  local snacks = vim.fn.stdpath("data") .. "/lazy/snacks.nvim"
  vim.opt.rtp:append(snacks)
  require("snacks.profiler").startup({ startup = { event = event } })
end

require("config.lazy")
