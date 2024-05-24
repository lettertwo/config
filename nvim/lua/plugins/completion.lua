local has_words_before = function()
  if vim.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt" then
    return false
  end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
end

return {
  -- Snippets
  {
    "garymjr/nvim-snippets",
    dependencies = { "rafamadriz/friendly-snippets" },
    keys = {
      {
        "<Tab>",
        function()
          if vim.snippet.active({ direction = 1 }) then
            vim.schedule(function()
              vim.snippet.jump(1)
            end)
            return
          end
          return "<Tab>"
        end,
        expr = true,
        silent = true,
        mode = "i",
      },
      {
        "<Tab>",
        function()
          vim.schedule(function()
            vim.snippet.jump(1)
          end)
        end,
        expr = true,
        silent = true,
        mode = "s",
      },
      {
        "<S-Tab>",
        function()
          if vim.snippet.active({ direction = -1 }) then
            vim.schedule(function()
              vim.snippet.jump(-1)
            end)
            return
          end
          return "<S-Tab>"
        end,
        expr = true,
        silent = true,
        mode = { "i", "s" },
      },
    },
    opts = {
      create_autocmd = false,
      create_cmp_source = true,
      friendly_snippets = true,
    },
  },

  {
    "hrsh7th/nvim-cmp",
    version = false,
    event = "InsertEnter",
    dependencies = {
      { "hrsh7th/cmp-nvim-lsp" },
      { "tzachar/cmp-fuzzy-buffer", dependencies = { "tzachar/fuzzy.nvim" } },
      { "tzachar/cmp-fuzzy-path", dependencies = { "tzachar/fuzzy.nvim" } },
      { "hrsh7th/cmp-nvim-lua" },
      { "hrsh7th/cmp-cmdline" },
      { "dmitmel/cmp-cmdline-history" },
      { "petertriho/cmp-git" },
      { "garymjr/nvim-snippets" },
    },
    config = function()
      local cmp = require("cmp")
      local icons = require("config").icons

      local function enter(fallback)
        if cmp.visible() and cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace }) then
          return
        end
        fallback()
      end

      local function space()
        if cmp.visible() then
          if not cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }) then
            return
          end
        else
          cmp.complete()
        end
      end

      local function right(fallback)
        if cmp.visible() then
          if not cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }) then
            return
          end
        else
          fallback()
        end
      end

      local function tab(fallback)
        local copilot_ok, copilot = pcall(require, "copilot.suggestion")

        if copilot_ok and copilot and copilot.is_visible() then
          copilot.accept()
        elseif cmp.visible() then
          cmp.select_next_item()
          return
        elseif vim.snippet.active({ direction = 1 }) then
          vim.snippet.jump(1)
        elseif has_words_before() then
          cmp.complete()
        else
          fallback()
        end
      end

      local function stab(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif vim.snippet.active({ direction = -1 }) then
          vim.snippet.jump(-1)
        else
          fallback()
        end
      end

      ---@diagnostic disable-next-line: missing-fields
      cmp.setup({
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
        confirm_opts = {
          behavior = cmp.ConfirmBehavior.Replace,
          select = false,
        },
        experimental = {
          ghost_text = false, -- let copilot haunt us instead
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item(),
          ["<C-j>"] = cmp.mapping.select_next_item(),
          ["<Up>"] = cmp.mapping.select_prev_item(),
          ["<Down>"] = cmp.mapping.select_next_item(),
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          ["<C-e>"] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
          }),
          ["<C-Space>"] = cmp.mapping(space, { "i", "c" }),
          -- ["<CR>"] = cmp.mapping(enter, { "i", "c" }),
          ["<cr>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
          }),
          ["<Right>"] = cmp.mapping(right, { "i", "c" }),
          ["<Tab>"] = cmp.mapping(tab, { "i", "c" }),
          ["<S-Tab>"] = cmp.mapping(stab, { "i", "c" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "nvim_lua", dup = 0 },
          { name = "snippets" },
        }, {
          { name = "fuzzy_buffer", keyword_length = 4 },
          { name = "fuzzy_path" },
        }),
        formatting = {
          expandable_indicator = true,
          fields = {
            cmp.ItemField.Abbr,
            cmp.ItemField.Kind,
            cmp.ItemField.Menu,
          },
          format = function(_, item)
            local MAX_ABBR_WIDTH, MAX_MENU_WIDTH = 25, 30
            local ellipsis = icons.dots

            item.kind = vim.trim(icons.kinds[item.kind]) .. " [" .. item.kind .. "]"
            -- Truncate the label.
            if vim.api.nvim_strwidth(item.abbr) > MAX_ABBR_WIDTH then
              item.abbr = vim.fn.strcharpart(item.abbr, 0, MAX_ABBR_WIDTH) .. ellipsis
            end

            -- Truncate the description part.
            if vim.api.nvim_strwidth(item.menu or "") > MAX_MENU_WIDTH then
              item.menu = vim.fn.strcharpart(item.menu, 0, MAX_MENU_WIDTH) .. ellipsis
            end

            return item
          end,
        },
      })

      -- Configuration for specific filetypes
      ---@diagnostic disable-next-line: missing-fields
      cmp.setup.filetype("gitcommit", {
        sources = cmp.config.sources({
          { name = "cmp_git" },
        }, {
          { name = "fuzzy_buffer" },
        }),
      })

      ---@diagnostic disable-next-line: missing-fields
      cmp.setup.filetype("zsh", {
        sources = cmp.config.sources({
          { name = "zsh" },
        }, {
          { name = "fuzzy_buffer" },
        }),
      })

      ---@diagnostic disable-next-line: missing-fields
      cmp.setup.filetype("fish", {
        sources = cmp.config.sources({
          { name = "fish" },
        }, {
          { name = "fuzzy_buffer" },
        }),
      })

      ---@diagnostic disable-next-line: missing-fields
      cmp.setup.filetype("dap-repl", {
        sources = cmp.config.sources({
          { name = "dap" },
        }, {
          { name = "fuzzy_buffer" },
        }),
      })

      -- cmdline completion
      ---@diagnostic disable-next-line: missing-fields
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline({
          ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "c" }),
          ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "c" }),
        }),
        sources = cmp.config.sources({
          { name = "fuzzy_path" },
        }, {
          { name = "cmdline" },
          { name = "cmdline_history" },
        }),
      })

      -- search completion
      ---@diagnostic disable-next-line: missing-fields
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline({
          ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "c" }),
          ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "c" }),
        }),
        sources = { { name = "fuzzy_buffer" } },
      })
    end,
  },
}
