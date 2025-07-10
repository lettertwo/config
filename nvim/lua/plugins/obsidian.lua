-- TODO: get this from env or something
local VAULT_DIR = vim.fn.expand("~") .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/lettertwo"

return {
  {
    "obsidian-nvim/obsidian.nvim",
    lazy = true,
    event = { "BufReadPre " .. VAULT_DIR .. "/**.md" },
    cmd = { "ObsidianOpen", "ObsidianNew", "ObsidianSearch", "ObsidianQuickSwitch", "ObsidianToday" },
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
    dependencies = {
      -- Required.
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        -- TODO: get this from env or something
        {
          name = "lettertwo",
          path = VAULT_DIR,
        },
      },
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
      -- https://github.com/Vinzent03/obsidian-advanced-uri
      use_advanced_uri = true,

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

      mappings = {
        -- TODO: buffer mappings for these:
        -- :ObsidianLink [QUERY] to link an inline visual selection of text to a note. This command has one optional argument: a query that will be used to resolve the note by ID, path, or alias. If not given, the selected text will be used as the query.
        -- :ObsidianLinkNew [TITLE] to create a new note and link it to an inline visual selection of text. This command has one optional argument: the title of the new note. If not given, the selected text will be used as the title.
        -- :ObsidianLinks to collect all links within the current buffer into a picker window.
        -- :ObsidianExtractNote [TITLE] to extract the visually selected text into a new note and link to it.
        -- :ObsidianPasteImg [IMGNAME] to paste an image from the clipboard into the note at the cursor position by saving it to the vault and adding a markdown image link. You can configure the default folder to save images to with the attachments.img_folder option.
        -- :ObsidianRename [NEWNAME] [--dry-run] to rename the note of the current buffer or reference under the cursor, updating all backlinks across the vault. Since this command is still relatively new and could potentially write a lot of changes to your vault, I highly recommend committing the current state of your vault (if you're using version control) before running it, or doing a dry-run first by appending "--dry-run" to the command, e.g. :ObsidianRename new-id --dry-run.
        -- :ObsidianFollowLink [vsplit|hsplit] to follow a note reference under the cursor, optionally opening it in a vertical or horizontal split.
        -- :ObsidianToggleCheckbox to cycle through checkbox options.

        -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
        ["gf"] = {
          action = function()
            return require("obsidian").util.gf_passthrough()
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
        -- Smart action depending on context, either follow link or toggle checkbox.
        ["<cr>"] = {
          action = function()
            return require("obsidian").util.smart_action()
          end,
          opts = { buffer = true, expr = true },
        },
      },

      ui = {
        enable = false, -- disabled to allow markdown.nvim to handle rendering
        -- TODO: extract this config and share with mkdnflow todo.symbols
        -- checkboxes = {
        --   -- NOTE: the 'char' value has to be a single character
        --   [" "] = { char = icons.task.todo, hl_group = "ObsidianTodo" },
        --   ["x"] = { char = icons.task.done, hl_group = "ObsidianDone" },
        --   [">"] = { char = icons.task.active, hl_group = "ObsidianRightArrow" },
        --   ["~"] = { char = icons.task.cancelled, hl_group = "ObsidianTilde" },
        --   ["!"] = { char = icons.task.important, hl_group = "ObsidianImportant" },
        --
        --   -- You can also add more custom ones...
        -- },
        -- external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
      },
    },
  },
  -- {
  --   "MeanderingProgrammer/render-markdown.nvim",
  --   enabled = false,
  --   dependencies = {
  --     "nvim-treesitter/nvim-treesitter", -- Mandatory
  --     "echasnovski/mini.icons",
  --   },
  --   ft = { "markdown" },
  --   ---@module 'render-markdown'
  --   ---@type render.md.UserConfig
  --   opts = {
  --     latex_enabled = false,
  --     -- Characters that will replace the # at the start of headings
  --     headings = { "󰼏 ", "󰎨 ", "󰼑 ", "󰎲 ", "󰼓 ", "󰎴 " },
  --     -- Character to use for the horizontal break
  --     -- dash = {"─"},
  --     -- Character to use for the bullet points in lists
  --     bullets = { "●", "○", "◆", "◇" },
  --     checkbox = {
  --       -- Character that will replace the [ ] in unchecked checkboxes
  --       unchecked = icons.task.todo,
  --       -- Character that will replace the [x] in checked checkboxes
  --       checked = icons.task.done,
  --       -- TODO: Figure out how to add these other states
  --       --   [" "] = { char = icons.task.todo, hl_group = "ObsidianTodo" },
  --       --   ["x"] = { char = icons.task.done, hl_group = "ObsidianDone" },
  --       --   [">"] = { char = icons.task.active, hl_group = "ObsidianRightArrow" },
  --       --   ["~"] = { char = icons.task.cancelled, hl_group = "ObsidianTilde" },
  --       --   ["!"] = { char = icons.task.important, hl_group = "ObsidianImportant" },
  --     },
  --     -- Character that will replace the > at the start of block quotes
  --     quote = "▋",
  --     -- Symbol / text to use for different callouts
  --     callout = {
  --       note = "󰋽 Note",
  --       tip = "󰌶 Tip",
  --       important = "󰅾 Important",
  --       warning = "󰀪 Warning",
  --       caution = "󰳦 Caution",
  --     },
  --     -- Define the highlight groups to use when rendering various components
  --     highlights = {
  --       heading = {
  --         -- Background of heading line
  --         backgrounds = { "DiffAdd", "DiffChange", "DiffDelete" },
  --         -- Foreground of heading character only
  --         foregrounds = {
  --           "markdownH1",
  --           "markdownH2",
  --           "markdownH3",
  --           "markdownH4",
  --           "markdownH5",
  --           "markdownH6",
  --         },
  --       },
  --       -- Horizontal break
  --       dash = "LineNr",
  --       -- Code blocks
  --       code = "ColorColumn",
  --       -- Bullet points in list
  --       bullet = "Normal",
  --       checkbox = {
  --         -- Unchecked checkboxes
  --         unchecked = "@markup.list.unchecked",
  --         -- Checked checkboxes
  --         checked = "@markup.heading",
  --       },
  --       table = {
  --         -- Header of a markdown table
  --         head = "@markup.heading",
  --         -- Non header rows in a markdown table
  --         row = "Normal",
  --       },
  --       -- LaTeX blocks
  --       latex = "@markup.math",
  --       -- Quote character in a block quote
  --       quote = "@markup.quote",
  --       -- Highlights to use for different callouts
  --       callout = {
  --         note = "DiagnosticInfo",
  --         tip = "DiagnosticOk",
  --         important = "DiagnosticHint",
  --         warning = "DiagnosticWarn",
  --         caution = "DiagnosticError",
  --       },
  --     },
  --   },
  -- },
}
