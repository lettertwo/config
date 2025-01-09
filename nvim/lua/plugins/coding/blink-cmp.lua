return {
  "saghen/blink.cmp",
  ---@type fun(_, default_opts: blink.cmp.Config): blink.cmp.Config
  opts = function(_, default_opts)
    local cmp = require("blink.cmp")

    LazyVim.cmp.actions.show_or_ai_show = function()
      if not cmp.is_visible() then
        if LazyVim.cmp.actions.ai_hide then
          LazyVim.cmp.actions.ai_hide()
        end
        cmp.show()
        return true
      elseif LazyVim.cmp.actions.ai_show then
        LazyVim.cmp.actions.ai_show()
        cmp.hide()
        return true
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

      keymap = {
        preset = "none",

        ["<C-space>"] = { LazyVim.cmp.map({ "show_or_ai_show" }), "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },

        ["<CR>"] = { "accept", "fallback" },
        ["<Right>"] = { "accept", LazyVim.cmp.map({ "ai_accept_word" }), "fallback" },

        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-p>"] = { "select_prev", LazyVim.cmp.map({ "ai_select_prev" }), "fallback" },
        ["<Up>"] = { "select_prev", LazyVim.cmp.map({ "ai_select_next" }), "fallback" },

        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-n>"] = { "select_next", LazyVim.cmp.map({ "ai_select_next" }), "fallback" },
        ["<Down>"] = { "select_next", LazyVim.cmp.map({ "ai_accept_line" }), "fallback" },

        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-u>"] = { "scroll_documentation_up", "fallback" },

        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },

        ["<Tab>"] = { LazyVim.cmp.map({ "snippet_forward", "ai_accept" }), "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },
    }

    return vim.tbl_deep_extend("force", default_opts, opts)
  end,
}
