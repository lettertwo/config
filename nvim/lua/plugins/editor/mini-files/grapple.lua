local nsMiniFiles = vim.api.nvim_create_namespace("mini_files_grapple")
local autocmd = vim.api.nvim_create_autocmd
local _, grapple = pcall(require, "grapple")

local function augroup(name)
  return vim.api.nvim_create_augroup("MiniFiles_grapple_" .. name, { clear = true })
end

local M = {}

function M.setup()
  autocmd("User", {
    group = augroup("update"),
    pattern = "MiniFilesBufferUpdate",
    callback = function(args)
      local buf_id = args.data.buf_id
      for i = 1, vim.api.nvim_buf_line_count(buf_id) do
        local entry = MiniFiles.get_fs_entry(buf_id, i)
        if not entry or not entry.path then
          break
        end
        local ok, tag = pcall(grapple.name_or_index, { path = entry.path })
        if ok and tag then
          vim.api.nvim_buf_set_extmark(buf_id, nsMiniFiles, i - 1, 0, {
            -- TODO: get icon from config
            virt_text = { { "󰓹 ", "SnacksPickerSelected" } },
            virt_text_pos = "right_align",
            hl_mode = "combine",
          })
        end
      end
    end,
  })
end

return M
