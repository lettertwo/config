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
      vim.keymap.set("n", "co", "<Plug>(git-conflict-ours)")
      vim.keymap.set("n", "ct", "<Plug>(git-conflict-theirs)")
      vim.keymap.set("n", "cb", "<Plug>(git-conflict-both)")
      vim.keymap.set("n", "c0", "<Plug>(git-conflict-none)")
      vim.keymap.set("n", "n", "<Plug>(git-conflict-prev-conflict)")
      vim.keymap.set("n", "p", "<Plug>(git-conflict-next-conflict)")
    end,
  },
}
