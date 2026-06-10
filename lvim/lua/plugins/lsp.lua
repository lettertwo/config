return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        -- Proxy LazyVim code group from the builtin LSP group. See :help gra
        { "gr", proxy = "<leader>c", group = "LSP references/actions", icon = { icon = " ", color = "orange" } },
        -- "gra" is mapped in Normal and Visual mode to |vim.lsp.buf.code_action()|
        { "gra", desc = "Code action" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    cmd = { "LspInfo", "LspStart", "LspStop", "LspRestart" },
    keys = {
      {
        "<leader>cL",
        function()
          if next(vim.lsp.get_clients({ bufnr = 0 })) ~= nil then
            vim.cmd("LspStop")
            vim.notify("LSP stopped")
          else
            vim.cmd("LspStart")
            vim.notify("LSP started")
          end
        end,
        desc = "Toggle LSP clients",
      },
    },
    opts = function(_, opts)
      local function glance_diagnostics()
        -- TODO: Make float for diagnostics show lsp_lines
        return vim.diagnostic.open_float({ scope = "cursor" })
      end

      -- Show diagnostics popup on cursor hold
      Snacks.util.lsp.on(function(bufnr)
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
        servers = {
          ["*"] = {
          -- stylua: ignore
          keys = {
            { "<leader>.", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeAction" },
            { "grn", function() require("live-rename").rename() end, desc = "Rename (live-rename.nvim)" },
            -- Disable signature help binding in insert mode.
            -- blink.cmp has experimental signature help.
            -- { "<c-k>", false, mode = { "i" } },
          },
          },
        },
      })
    end,
  },
}
