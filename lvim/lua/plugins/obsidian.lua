-- Get vault directory from state file
local STATE_FILE = vim.fn.stdpath("state") .. "/obsidian_vault_dir.txt"

local function get_default_vault_location()
  -- macOS iCloud Obsidian location
  return vim.fn.escape(vim.fn.expand("~") .. [[/Library/Mobile Documents/iCloud~md~obsidian/Documents/]], " ")
end

local function read_vault_dir()
  local file = io.open(STATE_FILE, "r")
  if file then
    local path = file:read("*line")
    file:close()
    return path
      :gsub("\\ ", " ") -- Unescape spaces
      :gsub("%s+$", "") -- Trim trailing whitespace
  end
  return nil
end

local function save_vault_dir(path)
  local file = io.open(STATE_FILE, "w")
  if file then
    file:write(path)
    file:close()
  else
    error("Could not open state file for writing: " .. STATE_FILE)
  end
end

local VAULT_DIR = read_vault_dir()

return {
  {
    "obsidian-nvim/obsidian.nvim",
    cond = vim.uv.os_uname().sysname == "Darwin",
    event = VAULT_DIR and { "BufReadPre " .. VAULT_DIR .. "/**.md" } or nil,
    cmd = { "ObsidianSetup", "ObsidianOpen", "ObsidianNew", "ObsidianSearch", "ObsidianQuickSwitch", "ObsidianToday" },
    init = function()
      vim.api.nvim_create_user_command("ObsidianSetup", function()
        local path = vim.fn.input({
          prompt = "Enter Obsidian vault directory: ",
          default = get_default_vault_location(),
          completion = "file",
          cancelreturn = false,
        })
        if path and path ~= "" then
          local save_ok = pcall(save_vault_dir, path)
          if save_ok then
            VAULT_DIR = path
            vim.notify("Obsidian vault directory set to: " .. VAULT_DIR, vim.log.levels.INFO)
            return
          end
        end
        vim.notify("Obsidian vault directory not set!", vim.log.levels.ERROR)
      end, { desc = "Setup Obsidian vault directory" })
      if not VAULT_DIR then
        vim.notify("Obsidian vault directory not set. Use :ObsidianSetup to set it.", vim.log.levels.WARN)
      end
    end,
    keys = {
      { "<leader>oc", "<cmd>ObsidianNew<CR>", desc = "New note" },
      { "<leader>os", "<cmd>ObsidianSearch<CR>", desc = "Search" },
      { "<leader>oo", "<cmd>ObsidianQuickSwitch<CR>", desc = "Find note" },
      { "<leader>od", "<cmd>ObsidianDailies<CR>", desc = "Open dailies" },
      { "<leader>ot", "<cmd>ObsidianToday<CR>", desc = "Open Today" },
      { "<leader>op", "<cmd>ObsidianYesterday<CR>", desc = "Open Yesterday" },
      { "<leader>on", "<cmd>ObsidianTomorrow<CR>", desc = "Open Tomorrow" },
      { "<leader>oT", "<cmd>ObsidianTemplate<CR>", desc = "Insert from template" },
      { "<leader>o#", "<cmd>ObsidianTags<CR>", desc = "Search tags" },
    },
    opts = {
      workspaces = { { name = "vault", path = VAULT_DIR } },
      notes_subdir = "notes",
      new_notes_location = "notes_subdir",
      preferred_link_style = "markdown",
      daily_notes = {
        -- Optional, if you keep daily notes in a separate directory.
        folder = "Daily Notes",
        -- Optional, if you want to change the date format for daily notes.
        date_format = "%Y-%m-%d",
      },

      templates = {
        subdir = "Templates",
      },

      open = {
        -- https://github.com/Vinzent03/obsidian-advanced-uri
        use_advanced_uri = true,
      },

      note_id_func = function(title)
        assert(title, "title is required")
        return title
      end,

      completion = {
        nvim_cmp = false,
        blink = true,
        min_chars = 2,
      },

      picker = {
        -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', 'mini.pick' or 'snacks.pick'.
        name = "snacks.pick",
        -- Optional, configure key mappings for the picker. These are the defaults.
        -- Not all pickers support all mappings.
        note_mappings = {
          -- Create a new note from your query.
          new = "<C-x>",
          -- Insert a link to the selected note.
          insert_link = "<C-l>",
        },
        tag_mappings = {
          -- Add tag(s) to current note.
          tag_note = "<C-x>",
          -- Insert a tag at the current location.
          insert_tag = "<C-l>",
        },
      },
      callbacks = {
        enter_note = function(note)
          -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
          vim.keymap.set("n", "gf", function()
            if require("obsidian").util.cursor_link() then
              return "<cmd>Obsidian follow_link<cr>"
            else
              return "gf"
            end
          end, { expr = true, desc = "Go to file under cursor" })

          -- Smart action depending on context, either follow link or toggle checkbox.
          vim.keymap.set("n", "<cr>", function()
            return require("obsidian").util.smart_action()
          end, { buffer = true, expr = true, desc = "Obsidian smart action" })
        end,
      },

      ui = {
        enable = false, -- disabled to allow markdown.nvim to handle rendering
      },
    },
  },
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>o", group = "obsidian" },
      },
    },
  },
}
