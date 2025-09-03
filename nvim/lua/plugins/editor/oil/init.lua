return {
  {
    "stevearc/oil.nvim",
    -- Optional dependencies
    dependencies = { { "echasnovski/mini.icons", opts = {} } },
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
    cmd = { "Oil" },
    keys = {
      {
        "<leader>e",
        function()
          require("oil").open_float(nil, { preview = { horizontal = true } })
        end,
        desc = "File explorer (buffer)",
      },
      {
        "<leader>~",
        function()
          require("oil").open_float(vim.loop.cwd(), { preview = { horizontal = true } })
        end,
        desc = "File explorer (cwd)",
      },
    },
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      keymaps = {
        ["<CR>"] = "actions.select",
        ["<right>"] = "actions.select",
        ["L"] = "actions.select",
        ["<BS>"] = "actions.parent",
        ["<left>"] = "actions.parent",
        ["H"] = "actions.parent",
        ["J"] = "j",
        ["K"] = "k",
        ["~"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["w"] = {
          function()
            require("oil").save()
          end,
          desc = "Save changes",
        },

        ["?"] = "actions.show_help",
        ["."] = "actions.toggle_hidden",
        ["q"] = "actions.close",
        ["<esc>"] = "actions.close",

        ["<c-c>"] = "actions.close",
        ["<c-d>"] = "actions.preview_scroll_down",
        ["<c-u>"] = "actions.preview_scroll_up",
        ["<c-r>"] = "actions.refresh",
        ["<c-p>"] = "actions.preview",
        ["<c-h>"] = "actions.toggle_hidden",
        ["<c-y>"] = "actions.copy_to_system_clipboard",
        ["<c-q>"] = { "actions.send_to_qflist", opts = { only_matching_search = true, close = true } },
        ["<c-v>"] = { "actions.select", opts = { vertical = true } },
        ["<c-s>"] = { "actions.select", opts = { horizontal = true } },
        ["<c-e>"] = {
          function() end,
          desc = "Reveal in explorer",
        },

        ["<c-o>"] = {
          function()
            local entry = require("oil").get_cursor_entry()
            local dir = require("oil").get_current_dir()
            if dir ~= nil and entry ~= nil then
              local path = vim.fs.joinpath(dir, entry.name)
              if vim.system({ "open", "-R", path }) then
                require("oil").close()
              end
            end
          end,
          desc = "Reveal in finder",
        },

        ["<c-m>"] = {
          function()
            local grapple_ok, Grapple = pcall(require, "grapple")
            if grapple_ok then
              local entry = require("oil").get_cursor_entry()
              local dir = require("oil").get_current_dir()
              if dir ~= nil and entry ~= nil then
                local path = vim.fs.joinpath(dir, entry.name)
                Grapple.toggle({ path = path })
                require("plugins.editor.oil.grapple").add_grapple_extmarks(0)
              end
            end
          end,
          desc = "Toggle tag",
        },
      },
      use_default_keymaps = false,
      -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
      -- Set to false if you want some other plugin (e.g. netrw) to open when you edit directories.
      default_file_explorer = true,
      -- Id is automatically added at the beginning, and name at the end
      -- See :help oil-columns
      columns = {
        "icon",
        -- "permissions",
        -- "size",
        -- "mtime",
      },
      win_options = {
        number = false,
        relativenumber = false,
        cursorline = true,
      },
      -- Send deleted files to the trash instead of permanently deleting them (:help oil-trash)
      delete_to_trash = false,
      -- Skip the confirmation popup for simple operations (:help oil.skip_confirm_for_simple_edits)
      skip_confirm_for_simple_edits = true,
      -- Selecting a new/moved/renamed file or directory will prompt you to save changes first
      -- (:help prompt_save_on_select_new_entry)
      prompt_save_on_select_new_entry = true,
      lsp_file_methods = {
        -- Enable or disable LSP file operations
        enabled = true,
        -- Time to wait for LSP file operations to complete before skipping
        timeout_ms = 1000,
        -- Set to true to autosave buffers that are updated with LSP willRenameFiles
        -- Set to "unmodified" to only save unmodified buffers
        autosave_changes = "unmodified",
      },
      float = {
        max_width = 100,
        max_height = 0.4,
        border = "rounded",
        preview_split = "right",
        override = function(conf)
          conf.row = 1
          conf.col = 2
          return conf
        end,
      },
    },
    config = function(_, opts)
      local oil = require("oil")
      oil.setup(opts)

      vim.api.nvim_create_autocmd("User", {
        pattern = "OilActionsPost",
        callback = function(args)
          if args.data.err == nil then
            for _, action in ipairs(args.data.actions) do
              if action.type == "delete" then
                local path = action.url:match("^.*://(.*)$")
                local bufnr = vim.fn.bufnr(path)
                if bufnr == -1 then
                  return
                end
                Snacks.bufdelete.delete(bufnr)
              end
            end
          end
        end,
      })

      require("plugins.editor.oil.status").setup()
      require("plugins.editor.oil.severity").setup()
      require("plugins.editor.oil.grapple").setup()
    end,
  },
}
