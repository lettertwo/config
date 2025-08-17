local ns = vim.api.nvim_create_namespace("oil_grapple")

local M = {}

--- @param buffer number
function M.add_grapple_extmarks(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end

  local grapple_ok, Grapple = pcall(require, "grapple")
  if not grapple_ok then
    vim.error("grapple.nvim is not installed")
  end

  local oil_ok, oil = pcall(require, "oil")
  if not oil_ok then
    vim.error("oil.nvim is not installed")
  end

  vim.api.nvim_buf_clear_namespace(buffer, ns, 0, -1)

  local dir = oil.get_current_dir(buffer)
  if not dir then
    return
  end

  for i = 1, vim.api.nvim_buf_line_count(buffer) do
    local entry = oil.get_entry_on_line(buffer, i)

    if not dir or not entry then
      break
    end

    local path = vim.fs.joinpath(dir, entry.name)
    local ok, tag = pcall(Grapple.name_or_index, { path = path })
    if ok and tag then
      vim.api.nvim_buf_set_extmark(buffer, ns, i - 1, 0, {
        virt_text = { { LazyVim.config.icons.tag, "SnacksPickerSelected" } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
    end
  end
end

function M.setup()
  local augroupOilGrapple = vim.api.nvim_create_augroup("oil_grapple", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = augroupOilGrapple,
    pattern = "OilEnter",
    callback = function(e)
      if vim.b[e.buf].oil_grapple_started then
        return
      end

      vim.b[e.buf].oil_grapple_started = true

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave", "TextChanged" }, {
        group = augroupOilGrapple,
        buffer = e.buf,
        callback = function()
          M.add_grapple_extmarks(e.buf)
        end,
      })
    end,
  })
end

return M
