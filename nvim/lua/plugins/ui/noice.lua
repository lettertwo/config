return {
  {
    "folke/noice.nvim",
    opts = function()
      return {
        cmdline = {
          format = {
            -- execute shell command (:!)
            filter = {
              pattern = "^:%s*!",
              icon = "$",
              lang = "fish",
              opts = {
                border = {
                  text = { top = " exec shell command " },
                },
              },
            },
            -- replace file content with shell command output (:%!)
            f_filter = {
              pattern = "^:%s*%%%s*!",
              icon = " $",
              lang = "fish",
              opts = { border = { text = { top = " filter file " } } },
            },
            -- replace selection with shell command output (:'<,'>!)
            v_filter = {
              pattern = "^:%s*%'<,%'>%s*!",
              icon = " $",
              lang = "fish",
              opts = { border = { text = { top = " filter selection " } } },
            },
            -- substitute (:s/, :%s/)
            substitute = {
              pattern = "^:%%?s/",
              icon = " ",
              lang = "regex",
              opts = { border = { text = { top = " sub (old/new/) " } } },
            },
            -- substitute on visual selection (:'<,'>s/)
            v_substitute = {
              pattern = "^:%s*%'<,%'>s/",
              icon = "  ",
              lang = "regex",
              opts = { border = { text = { top = " sub selection (old/new/) " } } },
            },
          },
        },
        lsp = {
          hover = { enabled = false }, -- Using a custom hover handler.
        },
        presets = {
          long_message_to_split = false, -- long messages will be sent to a split
          command_palette = true, -- position the cmdline and popupmenu together
          lsp_doc_border = true, -- add a border to hover docs and signature help
        },
        commands = {
          console = {
            view = "console",
          },
        },
        -- routes = {
        --     {
        --       filter = {
        --         event = "notify",
        --         cond = function(message)
        --           return message.opts and message.opts.title == "TSC"
        --         end,
        --       },
        --       -- TODO: Figure out how to format these TSC messages
        --       -- watch mode doesn't show progress, but running TSC manually
        --       -- does show an indeterminate spinner.
        --       -- just routing the messages results in a every frame of the spinner
        --       -- to be shown as a separate message.
        --       -- format = "progress",
        --       -- format_done = "progress_done",
        --       -- throttle = 1000 / 10, -- frequency to update lsp progress message
        --       view = "mini",
        --     },
        -- },
      }
    end,
    -- stylua: ignore
    keys = {
      { "<S-Enter>", function() require("noice").redirect(vim.fn.getcmdline()) end, mode = "c", desc = "Redirect Cmdline" },
      { "<leader>xn", "<cmd>Noice console<cr>", desc = "Noice console" },
      { "<leader>xc", "<cmd>Noice console<cr>", desc = "Noice console" },
      { "<leader>xa", "<cmd>Noice all<cr>", desc = "Noice all" },
      { "<leader>xm", "<cmd>Noice last<cr>", desc = "Last noice message" },
      { "<leader>un", "<cmd>Noice dismiss<cr>", desc="Dismiss notifications" },
      { "<c-d>", function() if not require("noice.lsp").scroll(4) then return "<c-d>" end end, mode = { "n", "i", "s" }, silent = true, expr = true, desc = "Scroll forward" },
      { "<c-u>", function() if not require("noice.lsp").scroll(-4) then return "<c-u>" end end, mode = { "n", "i", "s" }, silent = true, expr = true, desc = "Scroll backward" },
    },
    config = function(_, opts)
      -- HACK: noice shows messages from before it was enabled,
      -- but this is not ideal when Lazy is installing plugins,
      -- so clear the messages in this case.
      if vim.o.filetype == "lazy" then
        vim.cmd([[messages clear]])
      end
      require("noice").setup(opts)

      local Docs = require("noice.lsp.docs")
      local Format = require("noice.lsp.format")

      ---@diagnostic disable-next-line: duplicate-set-field
      vim.lsp.buf.hover = function()
        local message = Docs.get("hover")

        if message:focus() then
          return
        end

        -- Add diagnostics to hover
        if vim.diagnostic.is_enabled() then
          -- HACK: Open the diagnostic float, extract the contents, and close it.
          local bufnr, winid = vim.diagnostic.open_float({ scope = "cursor" })

          if bufnr then
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

            for lineno, line in ipairs(lines) do
              -- NOTE: extmark locations are 0-indexed
              local row = lineno - 1
              local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, { row, 0 }, { row, -1 }, { details = true })

              for _, extmark in ipairs(extmarks) do
                local _, _, start_col, details = unpack(extmark)
                local hl_group, end_row, end_col = details.hl_group, details.end_row, details.end_col

                if end_row == row then
                  message:append(line:sub(start_col + 1, end_col + 1), hl_group)
                else
                  message:append(line:sub(start_col + 1), hl_group)
                end
              end

              if lineno < #lines then
                message:append("\n")
              end
            end
          end

          if winid then
            vim.api.nvim_win_close(winid, true)
          end
        end

        -- Add lsp info to hover.
        vim.lsp.buf_request(0, "textDocument/hover", function(client)
          return vim.lsp.util.make_position_params(0, client.offset_encoding)
        end, function(_, result, ctx)
          -- If LSP is slow to respond, the current buffer may have changed.
          if vim.api.nvim_get_current_buf() ~= ctx.bufnr then
            return
          end
          -- Based on https://github.com/folke/noice.nvim/blob/main/lua/noice/lsp/hover.lua
          if result and result.contents then
            if not message:is_empty() then
              Format.format(message, "---")
            end
            Format.format(message, result.contents, { ft = vim.bo[ctx.bufnr].filetype })
          end

          if message:is_empty() then
            if opts.lsp.hover.silent ~= true then
              vim.notify("No information available")
            end
            return
          end
          Docs.show(message)
        end)
      end
    end,
  },
}
