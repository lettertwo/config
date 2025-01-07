return {
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      local cmp = require("cmp")

      LazyVim.cmp.actions.select_next_item = function()
        if cmp.visible() then
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
          return true
        end
      end

      LazyVim.cmp.actions.select_prev_item = function()
        if cmp.visible() then
          cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
          return true
        end
      end

      LazyVim.cmp.actions.select_and_confirm = function()
        if cmp.visible() then
          LazyVim.create_undo()
          return cmp.confirm({
            select = true,
            behavior = cmp.ConfirmBehavior.Insert,
          })
        end
      end

      return vim.tbl_deep_extend("force", opts, {
        preselect = cmp.PreselectMode.None,
        completion = {
          autocomplete = false,
        },
        view = {
          entries = {
            name = "custom",
            selection_order = "near_cursor",
            follow_cursor = true,
          },
          docs = {
            auto_open = true,
          },
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        experimental = {
          ghost_text = true,
        },

        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
          ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          ["<C-e>"] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
          }),
          ["<C-n>"] = function(fallback)
            return LazyVim.cmp.map({ "select_next_item", "ai_select_next" }, fallback)()
          end,
          ["<C-p>"] = function(fallback)
            return LazyVim.cmp.map({ "select_prev_item", "ai_select_prev" }, fallback)()
          end,
          ["<Up>"] = function(fallback)
            return LazyVim.cmp.map({ "select_prev_item", "ai_select_next" }, fallback)()
          end,
          ["<Down>"] = function(fallback)
            return LazyVim.cmp.map({ "select_next_item", "ai_accept_line" }, fallback)()
          end,
          ["<Right>"] = function(fallback)
            return LazyVim.cmp.map({ "select_and_confirm", "ai_accept_word" }, fallback)()
          end,
          ["<Tab>"] = function(fallback)
            return LazyVim.cmp.map({ "snippet_forward", "select_next_item", "ai_accept" }, fallback)()
          end,
        }),
      })
    end,
  },
}
