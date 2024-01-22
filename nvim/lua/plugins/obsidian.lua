-- TODO: get this from env or something
local VAULT_DIR = vim.fn.expand("~") .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/lettertwo"

return {
  {
    "epwalsh/obsidian.nvim",
    lazy = true,
    ft = "markdown",
    event = { "BufReadPre " .. VAULT_DIR .. "/**.md" },
    cmd = { "ObsidianOpen", "ObsidianNew", "ObsidianSearch", "ObsidianQuickSwitch", "ObsidianToday" },
    keys = {
      { "<leader>oO", "<cmd>ObsidianOpen<CR>", desc = "Open Obsidian" },
      { "<leader>on", "<cmd>ObsidianNew<CR>", desc = "New note" },
      { "<leader>os", "<cmd>ObsidianSearch<CR>", desc = "Search" },
      { "<leader>oo", "<cmd>ObsidianQuickSwitch<CR>", desc = "Find note" },
      { "<leader>ot", "<cmd>ObsidianToday<CR>", desc = "Open Today" },
      { "<leader>oT", "<cmd>ObsidianTemplate<CR>", desc = "Insert from template" },
    },
    dependencies = {
      -- Required.
      "nvim-lua/plenary.nvim",
    },
    opts = {
      dir = VAULT_DIR,
      mappings = {

        ["gf"] = {
          action = function()
            if require("obsidian").util.cursor_on_markdown_link() then
              return "<cmd>ObsidianFollowLink<CR>"
            else
              return "gf"
            end
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
        -- Toggle check-boxes.
        ["<CR>"] = {
          action = function()
            local line = vim.api.nvim_get_current_line()
            for _, char in ipairs({ " ", "x", "~", ">", "-" }) do
              if string.match(line, "^%s*- %[" .. char .. "%].*") then
                return "<cmd>lua require('obsidian').util.toggle_checkbox()<CR>"
              end
            end
            return "<CR>"
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
      },
      daily_notes = {
        -- Optional, if you keep daily notes in a separate directory.
        folder = "Daily Notes",
        -- Optional, if you want to change the date format for daily notes.
        date_format = "%Y-%m-%d",
      },

      templates = {
        subdir = "Templates",
      },
      -- https://github.com/Vinzent03/obsidian-advanced-uri
      use_advanced_uri = true,
      ui = {
        checkboxes = {
          -- NOTE: the 'char' value has to be a single character
          [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
          ["x"] = { char = "", hl_group = "ObsidianDone" },
          [">"] = { char = "", hl_group = "ObsidianRightArrow" },
          ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },

          -- You can also add more custom ones...
        },
        external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
      },
    },
  },
}
