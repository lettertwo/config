local previewers = require("telescope.previewers")
local builtin = require("telescope.builtin")
local make_entry = require("telescope.make_entry")

---@param opts? GitDeltaOptions
local function git_commits(opts)
  opts = require("telescope._extensions.git_delta.config").get(opts)

  local pager = opts.pager

  local bufnr = opts.bufnr or nil
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local bufname = bufnr ~= nil and vim.api.nvim_buf_get_name(bufnr) or nil

  -- TODO: extract util for use here and in other pickers?
  local cmd = { "git", "-c", "core.pager=delta", "-c", "delta.pager=" .. pager, "show" }

  local picker_opts = vim.tbl_extend("force", opts, {
    bufnr = nil,
    pager = nil,
    previewer = previewers.new_termopen_previewer({
      get_command = function(entry)
        return vim.iter({ cmd, entry.value }):flatten():totable()
      end,
    }),
    entry_maker = make_entry.gen_from_git_commits(opts),
  })

  if bufname ~= nil then
    builtin.git_bcommits(picker_opts)
    -- TODO: support range
    -- elseif range ~= nil then
    --   builtin.git_bcommits_range(picker_opts)
  else
    builtin.git_commits(picker_opts)
  end
end

return git_commits
