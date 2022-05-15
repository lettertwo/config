local Cmp = {}

function Cmp.config()
  local _, cmp = pcall(require, "cmp")
  local _, luasnip = pcall(require, "luasnip")

  if not cmp or not luasnip then
    return
  end
  -- Set configuration for specific filetype.
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

  -- Use buffer source for '/'
  cmp.setup.cmdline("/", {
    mapping = cmp.mapping.preset.cmdline(),
    sources = { { name = "buffer" } },
  })

  -- Use cmdline & path source for ':'
  cmp.setup.cmdline(":", {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
      { name = "path" },
    }, {
      { name = "cmdline" },
    }),
  })

  local jumpable = require("lvim.core.cmp").methods.jumpable

  local jump_or_fallback = function(fallback)
    if jumpable() then
      if not luasnip.jump(1) then
        fallback()
      end
    else
      fallback()
    end
  end

  local confirm_copilot_or_fallback = function(fallback)
    -- If a cmp selection wasn't confirmed, accept copilot suggestion if present.
    local copilot_keys = vim.fn["copilot#Accept"]("")
    if copilot_keys ~= "" then
      vim.api.nvim_feedkeys(copilot_keys, "i", true)
    else
      fallback()
    end
  end

  local confirm = function()
    if cmp.confirm(lvim.builtin.cmp.confirm_opts) then
      if jumpable() then
        luasnip.jump(1)
      end
      return true
    end
    return false
  end

  local enter = function(fallback)
    if cmp.visible() and confirm() then
      return
    end
    jump_or_fallback(fallback)
  end

  local right = function(fallback)
    if cmp.visible() and confirm() then
      return
    end
    if jumpable() then
      jump_or_fallback(fallback)
    else
      confirm_copilot_or_fallback(fallback)
    end
  end

  local tab = function(fallback)
    -- If a cmp selection is active, confirm it.
    if cmp.visible() and cmp.get_selected_entry() ~= nil and confirm() then
      return
    end
    confirm_copilot_or_fallback(fallback)
  end

  lvim.builtin.cmp.sources = {
    { name = "nvim_lua" },
    { name = "nvim_lsp" },
    { name = "path" },
    { name = "luasnip" },
    { name = "buffer", keyword_length = 5 },
    { name = "calc" },
    { name = "emoji" },
    { name = "treesitter" },
    { name = "crates" },
    { name = "tmux" },
  }

  -- TODO: Figure out how to add hints for sources.
  -- cmp.config.source_names({
  --   nvim_lua = "(Lua)",
  -- })

  -- TODO: Figure out how to add "lukas-reineke/cmp-under-comparator"
  -- Also see https://github.com/tjdevries/config_manager/blob/master/xdg_config/nvim/after/plugin/completion.lua#L116
  -- lvim.builtin.cmp.sorting = {
  -- }

  lvim.builtin.cmp.mapping["<Down"] = cmp.mapping.select_next_item()
  lvim.builtin.cmp.mapping["<Up>"] = cmp.mapping.select_prev_item()
  lvim.builtin.cmp.mapping["<Right>"] = cmp.mapping(right, { "i", "c" })
  lvim.builtin.cmp.mapping["<CR>"] = cmp.mapping(enter, { "i", "c" })
  lvim.builtin.cmp.mapping["<Tab>"] = cmp.mapping(tab, { "i", "c" })
  lvim.builtin.cmp.mapping["<S-Tab>"] = cmp.config.disable
end

return Cmp
