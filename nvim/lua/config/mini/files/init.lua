local map = vim.keymap.set

---@class Config.MiniFiles
local MiniFilesConfig = {}

function MiniFilesConfig.setup()
  Config.add("nvim-mini/mini.nvim")

  require("mini.files").setup({
    -- Module mappings created only inside explorer.
    -- Use `''` (empty string) to not create one.
    mappings = {
      close = "q",
      go_in = "l",
      go_in_plus = "<CR>",
      go_out = "<BS>",
      go_out_plus = "h",
      reset = "!",
      reveal_cwd = "@",
      show_help = "g?",
      synchronize = "w",
      trim_left = "<",
      trim_right = ">",
    },

    options = {
      permanent_delete = true,
      use_as_default_explorer = true,
    },

    windows = {
      preview = true,
      width_focus = 50,
      width_nofocus = 15,
      width_preview = 70,
    },
  })

  local actions = require("config.mini.files.actions")

  map("n", "<leader>e", actions.open_buffer, { desc = "File explorer (buffer)" })
  map("n", "<leader>~", actions.open_cwd, { desc = "File explorer (cwd)" })

  Config.on("User", "MiniFilesBufferCreate", function(args)
    if args.data.buf_id ~= nil then
      -- stylua: ignore start
      map("n", "<esc>", actions.close,            { desc = "Close minifiles",  buffer = args.data.buf_id })
      map("n", "g.",    actions.toggle_dotfiles,  { desc = "Toggle dotfiles",  buffer = args.data.buf_id })
      map("n", "<C-.>", actions.files_set_cwd,    { desc = "Set cwd",          buffer = args.data.buf_id })
      map("n", "<C-s>", actions.split,            { desc = "Open in split",    buffer = args.data.buf_id })
      map("n", "<C-v>", actions.vsplit,           { desc = "Open in vsplit",   buffer = args.data.buf_id })
      map("n", "<C-o>", actions.reveal_in_finder, { desc = "Reveal in finder", buffer = args.data.buf_id })
      -- stylua: ignore end
    end
  end)

  require("config.mini.files.status").setup()
  require("config.mini.files.severity").setup()
end

return MiniFilesConfig
