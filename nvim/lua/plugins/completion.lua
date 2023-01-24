local source_labels = {
  nvim_lsp = "[LSP]",
  nvim_lsp_signature_help = "[Sig]",
  nvim_lsp_document_symbol = "[Symbol]",
  nvim_lua = "[Lua]",
  buffer = "[Buf]",
  path = "[Path]",
  emoji = "[Emoji]",
  calc = "[Calc]",
  cmdline = "[Cmd]",
  cmdline_history = "[History]",
  git = "[Git]",
  luasnip = "[Snip]",
}

local has_words_before = function()
  if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
    return false
  end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
end

-- Accept copilot suggestion if present.
local function confirm_copilot_or_fallback(fallback)
  local copilot_status_ok, copilot_keys = pcall(vim.fn["copilot#Accept"], "")
  if copilot_status_ok and copilot_keys ~= "" then
    return vim.api.nvim_feedkeys(copilot_keys, "i", true)
  end
  fallback()
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
    "github/copilot.vim",
    event = "InsertEnter",
    init = function()
      -- Accepting copilot suggestions is managged via nvim-cmp plugins.
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    version = false,
    event = "InsertEnter",
    dependencies = {
      { "hrsh7th/cmp-buffer" },
      { "hrsh7th/cmp-nvim-lsp" },
      { "hrsh7th/cmp-nvim-lsp-signature-help" },
      { "hrsh7th/cmp-nvim-lsp-document-symbol" },
      { "hrsh7th/cmp-path" },
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
        confirm_copilot_or_fallback(fallback)
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

      cmp.setup({
        enabled = function()
          if vim.bo.ft == "TelescopePrompt" then
            return false
          end
          return true
        end,
        -- view = {
        -- -- TODO: Figure out how to get this to work with noice.
        --   entries = "native",
        -- },
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
          ghost_text = false, -- let copilot haunt us instead
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item(),
          ["<C-j>"] = cmp.mapping.select_next_item(),
          ["<Up>"] = cmp.mapping.select_prev_item(),
          ["<Down>"] = cmp.mapping.select_next_item(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
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
          { name = "nvim_lsp" },
          { name = "nvim_lsp_document_symbol" },
          { name = "nvim_lsp_signature_help" },
          { name = "nvim_lua", dup = 0 },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
          { name = "calc" },
          { name = "emoji" },
          { name = "treesitter" },
          { name = "crates" },
        }),
        formatting = {
          fields = {
            cmp.ItemField.Kind,
            cmp.ItemField.Abbr,
            cmp.ItemField.Menu,
          },
          format = function(entry, item)
            local icons = require("config").icons.kinds
            item.kind = icons[item.kind]
            item.menu = source_labels[entry.source.name]
            return item
          end,
        },
      })

      -- Configuration for specific filetypes
      cmp.setup.filetype("gitcommit", {
        sources = cmp.config.sources({
          { name = "cmp_git" },
        }, {
          { name = "buffer" },
        }),
      })

      cmp.setup.filetype("zsh", {
        sources = cmp.config.sources({
          { name = "zsh" },
        }, {
          { name = "buffer" },
        }),
      })

      cmp.setup.filetype("dap-repl", {
        sources = cmp.config.sources({
          { name = "dap" },
        }, {
          { name = "buffer" },
        }),
      })

      -- cmdline completion
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline({
          ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "c" }),
          ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "c" }),
        }),
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline" },
          { name = "cmdline_history" },
        }),
      })

      -- search completion
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline({
          ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "c" }),
          ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "c" }),
        }),
        sources = { { name = "buffer" } },
      })
    end,
  },
}
