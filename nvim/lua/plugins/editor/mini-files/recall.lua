local nsMiniFiles = vim.api.nvim_create_namespace("mini_files_recall")
local autocmd = vim.api.nvim_create_autocmd
local _, MiniFiles = pcall(require, "mini.files")
local _, recall_util = pcall(require, "util.recall")

local function augroup(name)
  return vim.api.nvim_create_augroup("MiniFiles_recall_" .. name, { clear = true })
end

local M = {}

function M.setup()
  autocmd("User", {
    group = augroup("update"),
    pattern = "MiniFilesBufferUpdate",
    callback = function(args)
      local buf_id = args.data.buf_id
      local marked_files = recall_util and recall_util.iter_marked_files():totable() or nil
      if marked_files and #marked_files then
        -- Update extmarks for each file entry
        for i = 1, vim.api.nvim_buf_line_count(buf_id) do
          local entry = MiniFiles.get_fs_entry(buf_id, i)
          if not entry or not entry.path then
            break
          end

          local normalized_path = recall_util.normalize_filepath(entry.path)
          if vim.list_contains(marked_files, normalized_path) then
            vim.api.nvim_buf_set_extmark(buf_id, nsMiniFiles, i - 1, 0, {
              virt_text = { { LazyVim.config.icons.tag, "@tag" } },
              virt_text_pos = "right_align",
              hl_mode = "combine",
            })
          end
        end
      end
    end,
  })
end

return M
