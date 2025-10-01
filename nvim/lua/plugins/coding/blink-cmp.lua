return {
  "saghen/blink.cmp",
  ---@type fun(_, default_opts: blink.cmp.Config): blink.cmp.Config
  opts = function(_, default_opts)
    local cmp = require("blink.cmp")

    -- Disable lsp inline completion when cycling cmp menu items,
    -- allowing their ghost text to be visible without conflict.
    local group = vim.api.nvim_create_augroup("blink-cmp-inline", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      pattern = "BlinkCmpListSelect",
      group = group,
      callback = function()
        if cmp.is_visible() and cmp.get_selected_item() ~= nil then
          vim.lsp.inline_completion.enable(false)
        end
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      pattern = "BlinkCmpMenuClose",
      group = group,
      callback = function()
        vim.lsp.inline_completion.enable(true)
      end,
    })

    LazyVim.cmp.actions.show_or_inline_show = function()
      if not cmp.is_visible() and cmp.show() then
        return true
      else
        cmp.hide()
        if not vim.lsp.inline_completion.is_enabled() then
          vim.lsp.inline_completion.enable(true)
          return true
        end
      end
    end

    LazyVim.cmp.actions.inline_select_prev = function()
      if vim.lsp.inline_completion.is_enabled() then
        vim.lsp.inline_completion.select({ count = -1 })
        return true
      end
    end

    LazyVim.cmp.actions.inline_select_next = function()
      if vim.lsp.inline_completion.is_enabled() then
        vim.lsp.inline_completion.select({ count = 1 })
        return true
      end
    end

    LazyVim.cmp.actions.inline_accept = function()
      if vim.lsp.inline_completion.is_enabled() then
        return vim.lsp.inline_completion.get()
      end
    end

    ---@type blink.cmp.Config
    local opts = {
      completion = {
        ghost_text = { enabled = true },
        documentation = { window = { border = "rounded" } },
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        menu = {
          border = "rounded",
          draw = { align_to = "cursor" },
        },
      },
      signature = { window = { border = "rounded" } },

      enabled = function()
        return not vim.tbl_contains(LazyVim.config.filetypes.ui, vim.bo.filetype)
          and vim.bo.buftype ~= "prompt"
          and vim.b.completion ~= false
      end,

      keymap = {
        preset = "none",

        ["<C-space>"] = { LazyVim.cmp.map({ "show_or_inline_show" }), "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },

        ["<CR>"] = { "accept", LazyVim.cmp.map({ "inline_accept" }), "fallback" },
        ["<Right>"] = { "accept", LazyVim.cmp.map({ "inline_accept" }), "fallback" },

        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-p>"] = { "select_prev", LazyVim.cmp.map({ "inline_select_prev" }), "fallback" },
        ["<Up>"] = { "select_prev", LazyVim.cmp.map({ "inline_select_next" }), "fallback" },

        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-n>"] = { "select_next", LazyVim.cmp.map({ "inline_select_next" }), "fallback" },
        ["<Down>"] = { "select_next", LazyVim.cmp.map({ "inline_accept" }), "fallback" },

        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-u>"] = { "scroll_documentation_up", "fallback" },

        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },

        ["<Tab>"] = { LazyVim.cmp.map({ "snippet_forward", "ai_nes", "inline_accept" }), "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },
    }

    return vim.tbl_deep_extend("force", default_opts, opts)
  end,
}
