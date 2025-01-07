return {
  {
    "dnlhc/glance.nvim",
    cmd = "Glance",
    opts = {
      detached = false,
      preview_win_opts = {
        cursorline = true,
        number = true,
        wrap = false,
      },
      border = {
        enable = true,
      },
      hooks = {
        before_open = function(results, open, jump, method)
          -- If there is only one result, and it is in the current buffer
          -- _or_ it is a definition, implementation, or declaration, then
          -- jump to it instead of showing glance.
          local should_jump = false

          if #results == 1 then
            local uri = vim.uri_from_bufnr(0)
            local target_uri = results[1].uri or results[1].targetUri

            should_jump = target_uri == uri
              or ({
                  definitions = true,
                  implementations = true,
                  declarations = true,
                })[method]
                == true
          end

          if should_jump then
            jump(results[1])
          else
            open(results)
          end
        end,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function()
      vim.list_extend(require("lazyvim.plugins.lsp.keymaps").get(), {
        { "grr", "<cmd>Glance references<cr>", desc = "Show references" },
        { "gri", "<cmd>Glance implementations<cr>", desc = "Show implementations" },
        { "grd", "<cmd>Glance definitions<cr>", desc = "Show definitions", has = "definition" },
        { "grD", "<cmd>Glance declarations<cr>", desc = "Show declarations" },
        { "grt", "<cmd>Glance type_definitions<cr>", desc = "Show type definitions" },
      })
    end,
  },
}
