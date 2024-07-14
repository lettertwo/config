local previewers = require("telescope.previewers")
local putils = require("telescope.previewers.utils")
local builtin = require("telescope.builtin")
local make_entry = require("telescope.make_entry")

---@param opts? GitDeltaOptions
local function git_status(opts)
  opts = require("telescope._extensions.git_delta.config").get(opts)

  local pager = opts.pager

  local picker_opts = vim.tbl_extend("force", opts, {
    bufnr = nil,
    pager = nil,
    previewer = previewers.new_termopen_previewer({
      get_command = function(entry)
        if entry.status == "D " then
          return {
            "git",
            "-c",
            "core.pager=delta",
            "-c",
            "delta.pager" .. pager,
            "show",
            "HEAD:",
            entry.value,
          }
        elseif entry.status == "??" then
          return { "bat", "--style=plain", "--pager=" .. pager, entry.value }
        end
        return {
          "git",
          "-c",
          "core.pager=delta",
          "-c",
          "delta.pager=" .. pager,
          "diff",
          "--",
          entry.value,
        }
      end,
    }),
    -- TODO: Figure out why this doesn't work
    -- entry_maker = make_entry.gen_from_git_status(opts),
  })

  builtin.git_status(picker_opts)
end

return git_status
