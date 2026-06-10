local function test()
  local Popup = require("nui.popup")
  local event = require("nui.utils.autocmd").event

  local function get_gutter_size()
    local initial_position = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_set_cursor(0, { initial_position[1], 0 })
    local col_start = vim.fn.wincol()
    vim.api.nvim_win_set_cursor(0, initial_position)
    return string.rep(" ", col_start - 1)
  end

  local popup = Popup({
    enter = true,
    focusable = true,
    relative = "cursor",
    position = {
      row = 1,
      col = 0,
    },
    -- border = {
    --   style = "rounded",
    --   text = {
    --     top = "[Choose Item]",
    --     top_align = "center",
    --   },
    -- },
    -- size = {
    --   width = "80%",
    --   height = "60%",
    -- },
  })

  -- get current line content

  local current_line = get_gutter_size() .. vim.api.nvim_get_current_line()

  local current_filetype = vim.bo.filetype

  -- mount/open the component
  popup:update_layout({ relative = "cursor", size = { width = "100%", height = 10 }, position = { row = 0, col = 0 } })
  popup:mount()

  -- unmount component when cursor leaves buffer
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  -- set content
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, true, { current_line })
  vim.api.nvim_set_option_value("modifiable", false, { buf = popup.bufnr })
  vim.api.nvim_set_option_value("filetype", current_filetype, { buf = popup.bufnr })
end

vim.keymap.set("n", "<leader>1", test, { noremap = true, silent = true })

-- reload this module on save
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  pattern = "test.lua",
  group = vim.api.nvim_create_augroup("__test__", { clear = true }),
  command = "luafile %",
})
