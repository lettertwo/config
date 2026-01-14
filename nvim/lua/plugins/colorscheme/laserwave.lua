local specifier = "laserwave"
local is_plugin_dir = vim.loop.cwd():find("laserwave.nvim", 1, true) ~= nil

if is_plugin_dir then
  vim.notify("Loading laserwave.nvim in dev mode from local development path: " .. vim.loop.cwd(), vim.log.levels.DEBUG)
  specifier = "laserwave.dev"
end

return {
  {
    "lettertwo/laserwave.nvim",
    dir = is_plugin_dir and vim.loop.cwd() or nil,
    config = function(_, opts)
      require(specifier).setup(opts)
    end,
  },
}
