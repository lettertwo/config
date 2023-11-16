local telescope_actions = require("telescope.actions")
local trouble = require("trouble.providers.telescope")
local actions = require("plugins.telescope.actions")

local function setnormal()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end

local function setinsert()
  vim.cmd([[startinsert]])
end

local function noop()
  -- print("BOOP!")
end

local M = {}

-- A 'quick' picker that starts in insert mode and expects the user to accept the current match with <CR>
function M.quick_picker(opts)
  return vim.tbl_deep_extend("force", {
    initial_mode = "insert",
    mappings = {
      i = {
        ["<esc>"] = telescope_actions.close,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        -- FIXME: These bindings only really work for file locations,
        -- so they shouldn't be enabled for every picker by default.
        -- The same goes for the other modes and pickers.
        ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
        ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
        ["<C-t>"] = trouble.smart_open_with_trouble,
        ["<C-e>"] = actions.open_in_file_explorer,
        ["<M-q>"] = false,
      },
      n = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
        ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
        ["<C-t>"] = trouble.smart_open_with_trouble,
        ["<C-e>"] = actions.open_in_file_explorer,
        ["<M-q>"] = false,
      },
    },
  }, opts or {})
end

-- A 'slow' picker that starts in normal mode and expects the user to use / to search
-- and <CR> to 'accept' the search and go back to normal mode.
function M.slow_picker(opts)
  return vim.tbl_deep_extend("force", {
    initial_mode = "normal",
    mappings = {
      i = {
        ["<cr>"] = setnormal,
        ["<esc>"] = telescope_actions.close,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
        ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
        ["<C-t>"] = trouble.open_with_trouble,
        ["<C-e>"] = actions.open_in_file_explorer,
        ["<M-q>"] = false,
      },
      n = {
        ["/"] = setinsert,
        i = noop,
        a = noop,
        I = noop,
        A = noop,
        R = noop,
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
        ["<C-n>"] = telescope_actions.cycle_history_next,
        ["<C-p>"] = telescope_actions.cycle_history_prev,
        ["<c-q>"] = actions.send_to_quickfix + actions.open_quickfix,
        ["<c-l>"] = actions.send_to_loclist + actions.open_loclist,
        ["<C-t>"] = trouble.open_with_trouble,
        ["<C-e>"] = actions.open_in_file_explorer,
        ["<M-q>"] = false,
      },
    },
  }, opts or {})
end

-- TODO: Extract into some kinda telescope-git-jump plugin?
-- things jump can do:
-- - jump to hunks in diff
-- - jump to conflicts in merge
-- - jump to matches in grep (not sure if this is all that useful?)
-- - jump to whitespace errors in diff
-- See https://github.com/git/git/tree/master/contrib/git-jump

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
      M.slow_picker({
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
