---@class GitHunksOptions
---@field bufnr number|nil Buffer number to get hunks from. Use 0 for current buffer or nil for all buffers

---@param opts? GitJumpOptions
local function git_hunks(opts)
  opts = require("telescope._extensions.git_jump.config").get(opts)
  local bufnr = opts.bufnr or nil
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local bufname = bufnr ~= nil and vim.api.nvim_buf_get_name(bufnr) or nil

  -- exclude deletes from the diff
  local cmd = { "git", "jump", "--stdout", "diff", "--diff-filter=d" }
  if bufname ~= nil then
    table.insert(cmd, bufname)
  end

  local conf = require("telescope.config").values
  local make_entry = require("telescope.make_entry")

  require("telescope.pickers")
    .new(opts, {
      finder = require("telescope.finders").new_oneshot_job(cmd, {
        entry_maker = function(line)
          local filename, lnum_string, col_string, extra = line:match("([^:]+):?(%d*):?(%d*):?(.*)")

          -- I couldn't find a way to use grep in new_oneshot_job so we have to filter here.
          -- return nil if filename is /dev/null because this means the file was deleted.
          if filename:match("^/dev/null") then
            return nil
          end

          local entry_maker = make_entry.gen_from_file(opts)(filename)
          local display = entry_maker.display
          function entry_maker.display(entry)
            local text, style = display(entry)

            local result = string.format("%s:%s", text, lnum_string)

            table.insert(style, { { #text, #result }, "TelescopeResultsLineNr" })

            return result, style
          end
          entry_maker.lnum = tonumber(lnum_string)
          return entry_maker
        end,
      }),
      sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
      -- previewer = require("telescope.config").values.grep_previewer({}),
      previewer = require("telescope.config").values.qflist_previewer({}),
      -- previewer = require("telescope.previewers").git_file_diff.new({}),
      results_title = "Git hunks",
      prompt_title = bufname ~= nil and "Git hunks (current buffer)" or "Git hunks",
      -- layout_strategy = "flex",
    })
    :find()
end

return git_hunks
