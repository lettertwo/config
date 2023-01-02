local persisted = require("persisted")

persisted.setup({
  use_git_branch = true,
  autosave = true,
  allowed_dirs = {
    "~/.config",
    "~/Code",
    "~/.local/share",
  },
  after_source = function()
    -- Reload the LSP servers
    vim.lsp.stop_client(vim.lsp.get_active_clients(), true)
  end,
  telescope = {
    before_source = function()
      -- Close all open buffers
      vim.api.nvim_input("<ESC>:%bd<CR>")
    end,
    after_source = function(session)
      print("Loaded session " .. session.name)
    end,
  },
})
