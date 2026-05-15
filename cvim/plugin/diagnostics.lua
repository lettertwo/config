-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
vim.diagnostic.config({
  -- Show all diagnostics as underline
  underline = { min = vim.diagnostic.severity.HINT, max = vim.diagnostic.severity.ERROR },
  update_in_insert = false, -- Don't update diagnostics when typing
  -- Show virtual text only for errors on the current line
  virtual_lines = false,
  virtual_text = {
    current_line = true,
    spacing = 4,
    source = "if_many",
    prefix = "●",
    severity = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.ERROR },
  },
  severity_sort = true,
  float = {
    severity = { min = vim.diagnostic.severity.HINT, max = vim.diagnostic.severity.ERROR },
  },
  signs = {
    -- Show signs on top of any other sign, but only for warnings and errors
    priority = 9999,
    severity = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.ERROR },
    text = {
      [vim.diagnostic.severity.ERROR] = Config.icons.diagnostics.Error,
      [vim.diagnostic.severity.WARN] = Config.icons.diagnostics.Warn,
      [vim.diagnostic.severity.HINT] = Config.icons.diagnostics.Hint,
      [vim.diagnostic.severity.INFO] = Config.icons.diagnostics.Info,
    },
  },
})

Config.once("BufReadPost", function()
  Config.add("folke/noice.nvim")

  local Docs = require("noice.lsp.docs")
  local Format = require("noice.lsp.format")

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.buf.hover = function()
    local message = Docs.get("hover")

    if message:focus() then
      return
    end

    -- Add diagnostics to hover
    if vim.diagnostic.is_enabled() then
      -- HACK: Open the diagnostic float, extract the contents, and close it.
      local bufnr, winid = vim.diagnostic.open_float({ scope = "cursor" })

      if bufnr then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        for lineno, line in ipairs(lines) do
          -- NOTE: extmark locations are 0-indexed
          local row = lineno - 1
          local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, { row, 0 }, { row, -1 }, { details = true })

          for _, extmark in ipairs(extmarks) do
            local _, _, start_col, details = unpack(extmark)
            local hl_group, end_row, end_col = details.hl_group, details.end_row, details.end_col

            if end_row == row then
              message:append(line:sub(start_col + 1, end_col + 1), hl_group)
            else
              message:append(line:sub(start_col + 1), hl_group)
            end
          end

          if lineno < #lines then
            message:append("\n")
          end
        end
      end

      if winid then
        vim.api.nvim_win_close(winid, true)
      end
    end

    -- Add lsp info to hover.
    vim.lsp.buf_request(0, "textDocument/hover", function(client)
      return vim.lsp.util.make_position_params(0, client.offset_encoding)
    end, function(_, result, ctx)
      -- If LSP is slow to respond, the current buffer may have changed.
      if vim.api.nvim_get_current_buf() ~= ctx.bufnr then
        return
      end
      -- Based on https://github.com/folke/noice.nvim/blob/main/lua/noice/lsp/hover.lua
      if result and result.contents then
        if not message:is_empty() then
          Format.format(message, "---")
        end
        Format.format(message, result.contents, { ft = vim.bo[ctx.bufnr].filetype })
      end

      if message:is_empty() then
        vim.notify("No information available")
        return
      end
      Docs.show(message)
    end)
  end

  local function scroll_forward()
    if not require("noice.lsp").scroll(4) then
      return "<c-d>"
    end
  end

  local function scroll_backward()
    if not require("noice.lsp").scroll(-4) then
      return "<c-u>"
    end
  end

  local function jump_forward()
    vim.diagnostic.jump({ on_jump = vim.lsp.buf.hover, count = 1 })
  end

  local function jump_backward()
    vim.diagnostic.jump({ on_jump = vim.lsp.buf.hover, count = -1 })
  end

  vim.keymap.set({ "n", "i", "s" }, "<c-d>", scroll_forward, { expr = true, desc = "Scroll forward" })
  vim.keymap.set({ "n", "i", "s" }, "<c-u>", scroll_backward, { expr = true, desc = "Scroll backward" })
  vim.keymap.set("n", "<leader>xj", jump_forward, { desc = "Next diagnostic" })
  vim.keymap.set("n", "<leader>xk", jump_backward, { desc = "Previous diagnostic" })
end)
