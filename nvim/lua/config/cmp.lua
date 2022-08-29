local cmp_status_ok, cmp = pcall(require, "cmp")
if not cmp_status_ok then
  return
end

local function confirm_copilot_or_fallback(fallback)
  -- If a cmp selection wasn't confirmed, accept copilot suggestion if present.
  local copilot_status_ok, copilot_keys = pcall(vim.fn["copilot#Accept"], "")
  if copilot_status_ok and copilot_keys ~= "" then
    return vim.api.nvim_feedkeys(copilot_keys, "i", true)
  end
  fallback()
end

local function enter(fallback)
  if cmp.visible() and cmp.confirm() then
    return
  end
  fallback()
end

local function right(fallback)
  if cmp.visible() and cmp.confirm() then
    return
  end
  confirm_copilot_or_fallback(fallback)
end

local function tab(fallback)
  -- If a cmp selection is active, confirm it.
  if cmp.visible() and cmp.get_selected_entry() ~= nil and cmp.confirm() then
    return
  end
  confirm_copilot_or_fallback(fallback)
end

local kind_icons = {
  Text = "",
  Method = "",
  Function = "",
  Constructor = "",
  Field = "",
  Variable = "",
  Class = "",
  Interface = "",
  Module = "",
  Property = "",
  Unit = "",
  Value = "",
  Enum = "",
  Keyword = "",
  Snippet = "",
  Color = "",
  File = "",
  Reference = "",
  Folder = "",
  EnumMember = "",
  Constant = "",
  Struct = "",
  Event = "",
  Operator = "",
  TypeParameter = "",
}

cmp.setup({
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "nvim_lsp_document_symbol" },
    { name = "nvim_lsp_signature_help" },
    { name = "nvim_lua", dup = 0 },
    { name = "under_comparator" },
    { name = "buffer" },
    { name = "path" },
    { name = "calc" },
    { name = "emoji" },
    { name = "treesitter" },
    { name = "crates" },
  }),
  mapping = cmp.mapping.preset.insert({
    ["<C-k>"] = cmp.mapping.select_prev_item(),
    ["<C-j>"] = cmp.mapping.select_next_item(),
    ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
    ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
    ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
    ["<C-e>"] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),
    ["<Up>"] = cmp.mapping.select_prev_item(),
    ["<Down>"] = cmp.mapping.select_next_item(),
    ["<Right>"] = cmp.mapping(right, { "i", "c" }),
    ["<CR>"] = cmp.mapping(enter, { "i", "c" }),
    ["<Tab>"] = cmp.mapping(tab, { "i", "c" }),
    ["<S-Tab>"] = cmp.config.disable,
  }),
  enabled = function()
    if vim.bo.ft == "TelescopePrompt" then
      return false
    end
    return true
  end,
  formatting = {
    fields = {
      cmp.ItemField.Kind,
      cmp.ItemField.Abbr,
      cmp.ItemField.Menu,
    },
    format = function(entry, vim_item)
      vim_item.kind = kind_icons[vim_item.kind]
      vim_item.menu = ({
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
      })[entry.source.name]
      return vim_item
    end,
  },
  sorting = {
    comparators = {
      cmp.config.compare.offset,
      cmp.config.compare.exact,
      cmp.config.compare.scopes,
      cmp.config.compare.score,
      require("cmp-under-comparator").under,
      cmp.config.compare.recently_used,
      cmp.config.compare.locality,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  },
  confirm_opts = {
    behavior = cmp.ConfirmBehavior.Replace,
    select = false,
  },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  experimental = {
    ghost_text = true,
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
  sources = {
    { name = "cmdline" },
    { name = "cmdline_history" },
    { name = "path" },
  },
})

-- search completion
cmp.setup.cmdline("/", {
  mapping = cmp.mapping.preset.cmdline({
    ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "c" }),
    ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "c" }),
  }),
  sources = { { name = "buffer" } },
})
cmp.setup.cmdline("?", {
  mapping = cmp.mapping.preset.cmdline({
    ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "c" }),
    ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "c" }),
  }),
  sources = { { name = "buffer" } },
})
