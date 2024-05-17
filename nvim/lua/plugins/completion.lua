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
    "L3MON4D3/LuaSnip",
    event = "BufReadPost",
    dependencies = {
      "rafamadriz/friendly-snippets",
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
      end,
    },
    opts = {
      history = true,
      delete_check_events = "TextChanged",
    },
    -- stylua: ignore
    keys = {
      {
        "<tab>",
        function()
          return require("luasnip").jumpable(1) and "<Plug>luasnip-jump-next" or "<tab>"
        end,
        expr = true, silent = true, mode = "i",
      },
      { "<tab>", function() require("luasnip").jump(1) end, mode = "s" },
      { "<s-tab>", function() require("luasnip").jump(-1) end, mode = { "i", "s" } },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    version = false,
    event = "InsertEnter",
    dependencies = {
      { "zbirenbaum/copilot-cmp", depenendencies = { "zbirenbaum/copilot.lua" } },
      { "tzachar/cmp-fuzzy-buffer", dependencies = { "tzachar/fuzzy.nvim" } },
      { "hrsh7th/cmp-nvim-lsp" },
      { "hrsh7th/cmp-nvim-lsp-signature-help" },
      { "hrsh7th/cmp-nvim-lsp-document-symbol" },
      { "tzachar/cmp-fuzzy-path", dependencies = { "tzachar/fuzzy.nvim" } },
      { "hrsh7th/cmp-nvim-lua" },
      { "hrsh7th/cmp-calc" },
      { "hrsh7th/cmp-cmdline" },
      { "dmitmel/cmp-cmdline-history" },
      { "petertriho/cmp-git" },
      { "saadparwaiz1/cmp_luasnip" },
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("copilot_cmp").setup({
        -- event = {
        --   on_menu_change = function(entry, menu)
        --     if #menu.items == 0 then
        --       cmp.close()
        --     end
        --   end,
        -- },
      })

      local function enter(fallback)
        if cmp.visible() and cmp.confirm() then
          return
        end
        fallback()
      end

      local function space()
        if cmp.visible() then
          if not cmp.confirm({ select = true }) then
            return
          end
        else
          cmp.complete()
        end
      end

      local function right(fallback)
        if not cmp.confirm({ select = true }) then
          return fallback()
        else
          cmp.complete()
        end
      end

      local function tab(fallback)
        if cmp.visible() then
          cmp.select_next_item()
          return
        elseif luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        elseif has_words_before() then
          cmp.complete()
        else
          fallback()
        end
      end

      local function stab(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end

      ---@diagnostic disable-next-line: missing-fields
      cmp.setup({
        enabled = function()
          if vim.bo.ft == "TelescopePrompt" then
            return false
          end
          return true
        end,
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
        snippet = {
          -- REQUIRED - you must specify a snippet engine :(
          -- See https://github.com/hrsh7th/nvim-cmp/issues/373
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
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
          ghost_text = true,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item(),
          ["<C-j>"] = cmp.mapping.select_next_item(),
          ["<Up>"] = cmp.mapping.select_prev_item(),
          ["<Down>"] = cmp.mapping.select_next_item(),
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping(space, { "i", "c" }),
          ["<C-e>"] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
          }),
          ["<CR>"] = cmp.mapping(enter, { "i", "c" }),
          ["<Right>"] = cmp.mapping(right, { "i", "c" }),
          ["<Tab>"] = cmp.mapping(tab, { "i", "c" }),
          ["<S-Tab>"] = cmp.mapping(stab, { "i", "c" }),
        }),
        sources = cmp.config.sources({
          { name = "copilot" },
          { name = "nvim_lsp" },
          { name = "nvim_lsp_document_symbol" },
          { name = "nvim_lsp_signature_help" },
          { name = "nvim_lua", dup = 0 },
          { name = "luasnip" },
        }, {
          { name = "fuzzy_buffer", max_item_count = 5 },
          { name = "fuzzy_path", max_item_count = 5 },
          { name = "calc" },
        }),
        sorting = {
          priority_weight = 2,
          comparators = vim.list_extend({
            require("copilot_cmp.comparators").prioritize,
          }, cmp.config.compare),
        },
        formatting = {
          expandable_indicator = true,
          fields = {
            cmp.ItemField.Abbr,
            cmp.ItemField.Kind,
          },
          format = function(_, item)
            local icons = require("config").icons.kinds
            item.kind = vim.trim(icons[item.kind]) .. " [" .. item.kind .. "]"
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
