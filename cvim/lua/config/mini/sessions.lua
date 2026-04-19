local map = vim.keymap.set

---@class Config.MiniSessions
local MiniSessionsConfig = {}

function MiniSessionsConfig.setup()
  Config.add("nvim-mini/mini.nvim")

  local MiniSessions = require("mini.sessions")
  MiniSessions.setup({
    autoread = false,
    autowrite = false, -- managed manually below so we can gate on need_save()
    directory = vim.fs.joinpath(vim.fn.stdpath("state"), "sessions"),
    file = "", -- disable local (per-cwd file) sessions
  })

  local SKIP_FT = { gitcommit = true, gitrebase = true, jj = true }
  local function need_save()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted
        and vim.bo[buf].buftype == ""
        and not SKIP_FT[vim.bo[buf].filetype]
        and vim.api.nvim_buf_get_name(buf) ~= ""
      then
        return true
      end
    end
    return false
  end

  Config.on("VimLeavePre", function()
    if need_save() then
      pcall(MiniSessions.write, Config.get_session_filename())
    end
  end, "Autosave session")

  vim.api.nvim_create_user_command("RestoreSession", function()
    MiniSessions.read(Config.get_session_filename())
  end, { desc = "Restore Session" })

  map("n", "<leader>qs", function() MiniSessions.select("read") end, { desc = "Select Session" })
  map("n", "<leader>ql", function() MiniSessions.read(Config.get_session_filename()) end, { desc = "Restore Session" })
  map("n", "<leader>qd", function() MiniSessions.delete(Config.get_session_filename()) end, { desc = "Delete Session" })
  map("n", "<leader>qR", "<cmd>restart lua MiniSessions.read(Config.get_session_filename())<cr>", { desc = "Restart" })
end


return MiniSessionsConfig
