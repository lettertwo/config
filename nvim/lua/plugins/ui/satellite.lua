---@module "satellite"
---@class RecallHandler: Satellite.Handler
local RecallHandler = {
  name = "recall_marks",
  config = {
    enable = true,
    overlap = true,
    priority = 100,
  },
}

function RecallHandler.enabled()
  return pcall(require, "util.recall")
end

function RecallHandler.setup(config, update)
  RecallHandler.config = vim.tbl_deep_extend("force", RecallHandler.config, config or {})
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("satellite_recall_marks", {}),
    pattern = "RecallUpdate",
    callback = vim.schedule_wrap(update),
  })
end

---@param bufnr number
---@param winid number
---@return Satellite.Mark[]
function RecallHandler.update(bufnr, winid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end

  return require("util.recall")
    .iter_marks(bufnr)
    :map(function(mark)
      local line = mark.pos and mark.pos[1] or 1
      return {
        pos = require("satellite.util").row_to_barpos(winid, line - 1),
        highlight = "@tag",
        symbol = LazyVim.config.icons.tag,
      }
    end)
    :totable()
end

return {
  -- scrollbar with decorations
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    cmd = { "SatelliteDisable", "SatelliteEnable", "SatelliteRefresh" },
    config = function(_, opts)
      require("satellite.handlers").register(RecallHandler)
      local recall_handler_enabled = RecallHandler.enabled()

      require("satellite").setup(vim.tbl_deep_extend("force", {}, opts or {}, {
        excluded_filetypes = LazyVim.config.filetypes.ui,
        handlers = {
          -- only enable default marks if recall handler is disabled
          marks = { enable = not recall_handler_enabled },
          recall_marks = { enable = recall_handler_enabled },
        },
      }))
    end,
  },
}
