local helpers_ok, helpers = pcall(require, "telescope-live-grep-args.helpers")

if not helpers_ok then
  error("telescope-live-grep-args is required for this extension")
end

local function grep(opts)
  if opts.word == true or opts.search ~= nil then
    local word = opts.search

    if word == nil then
      if vim.fn.mode() == "v" then
        local saved_reg = vim.fn.getreg("v")
        vim.cmd([[noautocmd sil norm! "vy]])
        word = vim.fn.getreg("v")
        vim.fn.setreg("v", saved_reg)
      else
        word = vim.fn.expand("<cword>")
      end
    end
    opts.default_text = helpers.quote(vim.trim(word))
  end

  return require("telescope").extensions.live_grep_args.live_grep_args(opts)
end

local M = {}

---@param opts GrepOptions
function M.grep(opts)
  opts = require("telescope._extensions.grep.config").get(opts)
  return grep(opts)
end

---@param opts GrepOptions
function M.relative(opts)
  opts = require("telescope._extensions.grep.config").get(opts)
  opts.cwd = require("telescope.utils").buffer_dir()
  opts.prompt_title = string.format("%s buffer dir", opts.prompt_title)
  return grep(opts)
end

---@param opts GrepOptions
function M.open(opts)
  opts = require("telescope._extensions.grep.config").get(opts)
  opts.search_dirs = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(bufnr) >= 1 then
      local file = vim.api.nvim_buf_get_name(bufnr)
      table.insert(opts.search_dirs, file)
    end
  end

  opts.prompt_title = string.format("%s open files", opts.prompt_title)
  return grep(opts)
end

return M
