-- TODO: Implement a MERGETOOL mode that:
--  - Activates the git-conflict plugin
--  - implements special keybinds for navigating between conflicts (git-conflict does some of this already)
--  - exits with error code if conflicts are not resolved

-- TODO: Other features:
-- folds for conflict markers

local function confirm_exit()
  local answer = vim.fn.confirm("There are unresolved conflicts. Are you sure you want to exit?", "&Yes\n&No", 2)
  if answer == 1 then
    vim.cmd("cq!") -- exit with error code
  end
end

return {
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    cond = vim.g.mergetool == true,
    dependencies = { "lewis6991/gitsigns.nvim" },
    opts = {
      default_mappings = false, -- disable buffer local mapping created by this plugin
      default_commands = true, -- disable commands created by this plugin
      disable_diagnostics = true, -- This will disable the diagnostics in a buffer whilst it is conflicted
      list_opener = "copen", -- command or function to open the conflicts list
    },

    config = function(_, opts)
      local conflict = require("git-conflict")
      conflict.setup(opts)

      local augroup = vim.api.nvim_create_augroup("mode.mergetool", { clear = true })

      vim.api.nvim_create_autocmd("VimLeavePre", {
        group = augroup,
        callback = function()
          for _, buf in vim.iter(vim.api.nvim_list_bufs()) do
            if conflict.conflict_count(buf) > 0 then
              return confirm_exit()
            end
          end
        end,
      })

      -- TODO: Replace these with submode mappings
      vim.keymap.set("n", "<leader>gco", "<cmd>GitConflictChooseOurs<cr>", { desc = "Choose ours" })
      vim.keymap.set("n", "<leader>gct", "<cmd>GitConflictChooseTheirs<cr>", { desc = "Choose theirs" })
      vim.keymap.set("n", "<leader>gch", "<cmd>GitConflictChooseOurs<cr>", { desc = "Choose left (ours)" })
      vim.keymap.set("n", "<leader>gcl", "<cmd>GitConflictChooseTheirs<cr>", { desc = "Choose right (theirs)" })
      vim.keymap.set("n", "<leader>gcb", "<cmd>GitConflictChooseBoth<cr>", { desc = "Choose both" })
      vim.keymap.set("n", "<leader>gcn", "<cmd>GitConflictChooseNone<cr>", { desc = "Choose none" })
      -- vim.keymap.set("n", "<leader>gn", "<Plug>(git-conflict-prev-conflict)")
      -- vim.keymap.set("n", "<leader>gp", "<Plug>(git-conflict-next-conflict)")
    end,
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>gc", group = "conflict" },
      },
    },
  },
  {
    "pmizio/typescript-tools.nvim",
    optional = true,
    cond = vim.g.mergetool ~= true and vim.g.difftool ~= true,
  },
  {
    "neovim/nvim-lspconfig",
    optional = true,
    cond = vim.g.mergetool ~= true and vim.g.difftool ~= true,
  },
  {
    "folke/persistence.nvim",
    optional = true,
    cond = vim.g.mergetool ~= true and vim.g.difftool ~= true,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    cond = vim.g.mergetool ~= true and vim.g.difftool ~= true,
  },
}
