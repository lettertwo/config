local Persisted = {}

function Persisted.config()
  require("persisted").setup({
    use_git_branch = true,
    allowed_dirs = {
      "~/.local/share",
      "~/.config",
      "~/Code",
    },
    after_source = function()
      -- Reload the LSP servers
      vim.lsp.stop_client(vim.lsp.get_active_clients())
    end,
    telescope = {
      before_source = function()
        -- Close all open buffers
        pcall(vim.cmd, "bufdo bwipeout")
      end,
      after_source = function(session)
        -- Change the git branch
        pcall(vim.cmd, "git checkout " .. session.branch)
      end,
    },
  })

  local _, telescope = pcall(require, "telescope")
  if telescope then
    telescope.load_extension("persisted")
  end

  lvim.builtin.which_key.mappings["S"] = { "<cmd>Telescope persisted<cr>", "Sessions" }
end

return Persisted
