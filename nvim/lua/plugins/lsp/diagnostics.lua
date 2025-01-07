return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local function glance_diagnostics()
        -- TODO: Make float for diagnostics show lsp_lines
        return vim.diagnostic.open_float({ scope = "cursor" })
      end

      local lsp = require("lazyvim.util").lsp

      -- Show diagnostics popup on cursor hold
      lsp.on_attach(function(_, bufnr)
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_create_autocmd("CursorHold", {
          group = vim.api.nvim_create_augroup("Diagnostics" .. bufnr, { clear = true }),
          buffer = bufnr,
          callback = function()
            if line ~= vim.api.nvim_win_get_cursor(0)[1] then
              glance_diagnostics()
            elseif col ~= vim.api.nvim_win_get_cursor(0)[2] then
              -- TODO: Make float show again if moved to another diagnostic on same line
            end
            line, col = unpack(vim.api.nvim_win_get_cursor(0))
          end,
        })
      end)

      return vim.tbl_deep_extend("force", opts, {
        diagnostics = {
          update_in_insert = true,
          underline = true,
          severity_sort = true,
          virtual_text = false,
          virtual_lines = false,
          float = {
            focusable = false,
            close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
            style = "minimal",
            border = "rounded",
            source = true,
            header = "",
            prefix = "",
          },
        },
      })
    end,
  },
}
