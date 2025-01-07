return {
  {
    "echasnovski/mini.pick",
    -- enabled = false,
    version = false,
    cmd = { "Pick" },
    dependencies = {
      { "echasnovski/mini.extra", version = false, config = true },
    },
    keys = {
      -- Custom
      { "<leader>r", '<cmd>Pick recent cwd="root"<cr>', desc = "Recent" },
      { "<leader>R", "<cmd>Pick recent<cr>", desc = "Recent" },
      { "<leader>*", '<cmd>Pick grep scope="word"<cr>', desc = "Grep (Word)", mode = { "n", "v" } },
      { "<leader>bg", '<cmd>Pick grep scope="buffers"<cr>', desc = "Grep (Buffers)" },
      { "<leader>sB", '<cmd>Pick grep scope="buffers"<cr>', desc = "Grep (Buffers)" },
      -- TODO: Implement lazy
      -- { "<leader>sP", '<cmd>Pick lazy<cr>', desc = "Plugins" },
      -- TODO: Implement yank
      -- { "<leader>sy", '<cmd>Pick yank<cr>', desc = "Yank history" },
      { "<leader>gC", '<cmd>Pick git_commits path="%"<cr>', desc = "Buffer Commits" },
      { "<leader>gB", "<cmd>Pick git_branches<cr>", desc = "Branches" },

      -- Mirroring LazyVim defaults
      { "<leader>,", "<cmd>Pick buffers<cr>", desc = "Switch Buffer" },
      { "<leader>/", '<cmd>Pick grep scope="buffers"<cr>', desc = "Grep (Buffers)" },
      { "<leader>:", "<cmd>Pick history<CR>", desc = "Command History" },
      { "<leader><space>", '<cmd>Pick files tool="fd"<cr>', desc = "Find Files" },
      -- find
      { "<leader>fb", "<cmd>Pick buffers<cr>", desc = "Switch Buffer" },
      -- TODO: Implement config_files
      -- { "<leader>fc", LazyVim.pick.config_files(), desc = "Find Config File" },
      { "<leader>ff", '<cmd>Pick files tool="fd" cwd="root"<cr>', desc = "Find Files" },
      { "<leader>fF", '<cmd>Pick files tool="fd"<cr>', desc = "Find Files (cwd)" },
      { "<leader>fg", "<cmd>Pick git_files<cr>", desc = "Find Files (git-files)" },
      -- TODO: Implement recent cwd="root"
      { "<leader>fr", '<cmd>Pick recent cwd="root"<cr>', desc = "Recent" },
      { "<leader>fR", "<cmd>Pick recent<cr>", desc = "Recent (cwd)" },
      -- git
      { "<leader>gc", "<cmd>Pick git_commits<CR>", desc = "Commits" },
      -- TODO: Implement git_status
      { "<leader>gs", "<cmd>Pick git_hunks<CR>", desc = "Status" },
      -- search
      { '<leader>s"', "<cmd>Pick registers<cr>", desc = "Registers" },
      -- TODO: implement autocommands?
      -- { "<leader>sa", "<cmd>Telescope autocommands<cr>", desc = "Auto Commands" },
      { "<leader>sb", '<cmd>Pick buf_lines scope="current"<cr>', desc = "Buffer" },
      { "<leader>sc", "<cmd>Pick history<CR>", desc = "Command History" },
      { "<leader>sC", "<cmd>Pick commands<cr>", desc = "Commands" },
      { "<leader>sd", '<cmd>Pick diagnostic scope="current"<cr>', desc = "Document Diagnostics" },
      { "<leader>sD", "<cmd>Pick diagnostic<cr>", desc = "Workspace Diagnostics" },
      { "<leader>sg", '<cmd>Pick grep cwd="root"<cr>', desc = "Grep (Root Dir)" },
      { "<leader>sG", '<cmd>Pick grep cwd="buffer"<cr>', desc = "Grep (Buffer Dir)" },
      { "<leader>sh", "<cmd>Pick help<cr>", desc = "Help Pages" },
      { "<leader>sH", "<cmd>Pick hl_groups<cr>", desc = "Search Highlight Groups" },
      { "<leader>sj", '<cmd>Pick list scope="jump"<cr>', desc = "Jumplist" },
      { "<leader>sk", "<cmd>Pick keymaps<cr>", desc = "Key Maps" },
      { "<leader>sl", '<cmd>Pick list scope="location"<cr>', desc = "Location List" },
      -- TODO: Implement man_pages?
      -- { "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
      { "<leader>sm", "<cmd>Pick marks<cr>", desc = "Jump to Mark" },
      { "<leader>so", "<cmd>Pick options<cr>", desc = "Options" },
      { "<leader>sR", "<cmd>Pick resume<cr>", desc = "Resume" },
      { "<leader>sq", '<cmd>Pick list scope="quickfix"<cr>', desc = "Quickfix List" },
      { "<leader>sw", '<cmd>Pick grep scope="word" cwd="root"<cr>', desc = "Word (Root Dir)", mode = { "n", "v" } },
      { "<leader>sW", '<cmd>Pick grep scope="word"<cr>', desc = "Word (cwd)", mode = { "n", "v" } },
      -- TODO: Implement colorscheme?
      -- { "<leader>uC", LazyVim.pick("colorscheme", { enable_preview = true }), desc = "Colorscheme with Preview" },
      { "<leader>ss", '<cmd>Pick lsp scope="document_symbol"<cr>', desc = "Goto Symbol" },
      { "<leader>sS", '<cmd>Pick lsp scope="workspace_symbol"<cr>', desc = "Goto Symbol (Workspace)" },
    },
    opts = function()
      local MiniPick = require("mini.pick")
      local Actions = require("plugins.editor.mini-pick.actions")
      local Pickers = require("plugins.editor.mini-pick.pickers")

      Pickers.setup()
      Actions.setup()

      return {
        -- Keys for performing actions. See `:h MiniPick-actions`.
        mappings = {
          -- caret_left = "<Left>",
          -- caret_right = "<Right>",
          --
          -- choose = "<CR>",
          -- choose_in_split = "<C-s>",
          -- choose_in_tabpage = "<C-t>",
          -- choose_in_vsplit = "<C-v>",
          choose_marked = "",
          --
          -- delete_char = "<BS>",
          -- delete_char_right = "<Del>",
          -- delete_left = "<C-u>",
          -- delete_word = "<C-w>",
          --
          mark = "<Tab>",
          mark_all = "",

          move_down = "<C-j>",
          move_start = "<C-g>",
          move_up = "<C-k>",
          --
          paste = "",

          scroll_down = "<C-d>",
          scroll_left = "<C-Left>",
          scroll_right = "<C-Right>",
          scroll_up = "<C-u>",

          stop = "<Esc>",

          toggle_info = "<C-h>",
          toggle_preview = "<C-l>",

          -- Refinmenent
          refine = "",
          refine_marked = "",
          rotate_picker_or_push_refine = {
            char = "<C-Space>",
            func = Actions.rotate_picker_or_push_refine,
          },
          delete_char = "",
          delete_char_or_pop_refine = {
            char = "<BS>",
            func = Actions.delete_char_or_pop_refine,
          },

          -- Quickfix
          send_to_quickfix = {
            char = "<C-q>",
            func = Actions.send_to_quickfix,
          },
        },

        -- General options
        options = {
          -- Whether to show content from bottom to top
          content_from_bottom = false,
          -- Whether to cache matches (more speed and memory on repeated prompts)
          use_cache = false,
        },

        -- Window related options
        window = {
          -- Float window config (table or callable returning it)
          config = function()
            return {
              width = vim.o.columns,
              height = math.floor(vim.o.lines * 0.333),
            }
          end,

          -- String to use as cursor in prompt
          prompt_cursor = "▏",

          -- String to use as prefix in prompt
          prompt_prefix = "  ",
        },
      }
    end,
    config = function(_, opts)
      local MiniPick = require("mini.pick")
      MiniPick.setup(opts)
      -- NOTE: MiniPick overrides paste to show a notification to use the
      -- `mappings.paste` action. However, that action requires specifying a register,
      -- which is not what we want to have to do when doing a 'native' paste.
      -- So, we override it _again_ to automatically insert the contents of the
      -- clipboard register.
      local paste_orig = vim.paste
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.paste = function(...)
        if not MiniPick.is_picker_active() then
          return paste_orig(...)
        end
        local register = vim.o.clipboard == "unnamedplus" and "+" or "*"
        local has_register, reg_contents = pcall(vim.fn.getreg, register)
        if not has_register then
          return
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        reg_contents = reg_contents:gsub("[\n\t]", " ")
        local query = MiniPick.get_picker_query() or {}
        for i = 1, vim.fn.strchars(reg_contents) do
          table.insert(query, vim.fn.strcharpart(reg_contents, i - 1, 1))
        end
        MiniPick.set_picker_query(query)
      end
    end,
  },
}
