local M = {}

function M.setup(dap, ui)
  ui.setup({
    mappings = {
      expand = { "<CR>", "<2-LeftMouse>" },
      open = "o",
      remove = "d",
      edit = "e",
      repl = "r",
      toggle = "t",
    },
    expand_lines = true,
    layouts = {
      {
        elements = {
          "scopes",
          "stacks",
        },
        size = 0.3,
        position = "right",
      },
      {
        elements = {
          "watches",
          "breakpoints",
        },
        size = 0.3,
        position = "bottom",
      },
    },
    floating = {
      -- max_height = nil,
      -- max_width = nil,
      border = "single",
      mappings = {
        close = { "q", "<Esc>" },
      },
    },
    windows = { indent = 1 },
    render = {
      max_type_length = nil,
    },
  })

  vim.api.nvim_command("au FileType dap-repl lua require('dap.ext.autocompl').attach()")
end

return M
