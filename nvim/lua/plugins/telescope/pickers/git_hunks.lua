-- TODO: Extract into some kinda telescope-git-jump plugin?
-- things jump can do:
-- - jump to hunks in diff
-- - jump to conflicts in merge
-- - jump to matches in grep (not sure if this is all that useful?)
-- - jump to whitespace errors in diff
-- See https://github.com/git/git/tree/master/contrib/git-jump

local M = {}

---@class GitHunksOptions
---@field bufnr number|nil Buffer number to get hunks from. Use 0 for current buffer or nil for all buffers

---@param opts? GitHunksOptions
function M.git_hunks(opts)
  local bufnr = opts and opts.bufnr or nil
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local bufname = bufnr ~= nil and vim.api.nvim_buf_get_name(bufnr) or nil

  local cmd = { "git", "jump", "--stdout", "diff" }
  if bufname ~= nil then
    table.insert(cmd, bufname)
  end

  require("telescope.pickers")
    .new(
      ---@diagnostic disable-next-line: param-type-mismatch
      require("plugins.telescope.pickers").slow_picker({
        finder = require("telescope.finders").new_oneshot_job(cmd, {
          entry_maker = function(line)
            local filename, lnum_string = line:match("([^:]+):(%d+).*")

            -- I couldn't find a way to use grep in new_oneshot_job so we have to filter here.
            -- return nil if filename is /dev/null because this means the file was deleted.
            if filename:match("^/dev/null") then
              return nil
            end

            return {
              value = filename,
              display = line,
              ordinal = line,
              filename = filename,
              lnum = tonumber(lnum_string),
            }
          end,
        }),
        sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
        -- previewer = require("telescope.config").values.grep_previewer({}),
        previewer = require("telescope.config").values.qflist_previewer({}),
        -- previewer = require("telescope.previewers").git_file_diff.new({}),
        results_title = "Git hunks",
        prompt_title = "Git hunks",
        -- layout_strategy = "flex",
      }),
      {}
    )
    :find()
end

return M
