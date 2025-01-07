return {
  "saghen/blink.cmp",
  ---@type fun(_, default_opts: blink.cmp.Config): blink.cmp.Config
  opts = function(_, default_opts)
    local cmp = require("blink.cmp")

    LazyVim.cmp.actions.select_next_item = function()
      if cmp.is_visible() then
        cmp.select_next()
        return true
      end
    end

    LazyVim.cmp.actions.select_prev_item = function()
      if cmp.is_visible() then
        cmp.select_prev()
        return true
      end
    end

    LazyVim.cmp.actions.select_and_confirm = function()
      if cmp.is_visible() then
        LazyVim.create_undo()
        return cmp.select_and_accept()
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
          auto_show = false,
          border = "rounded",
          draw = { align_to = "cursor" },
        },
      },
      signature = { window = { border = "rounded" } },

      keymap = {
        preset = "default",
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-u>"] = { "scroll_documentation_up", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        ["<C-n>"] = { LazyVim.cmp.map({ "select_next_item", "ai_select_next" }), "fallback" },
        ["<C-p>"] = { LazyVim.cmp.map({ "select_prev_item", "ai_select_prev" }), "fallback" },
        ["<Up>"] = { LazyVim.cmp.map({ "select_prev_item", "ai_select_next" }), "fallback" },
        ["<Down>"] = { LazyVim.cmp.map({ "select_next_item", "ai_accept_line" }), "fallback" },
        ["<Right>"] = { LazyVim.cmp.map({ "select_and_confirm", "ai_accept_word" }), "fallback" },
        ["<Tab>"] = { LazyVim.cmp.map({ "snippet_forward", "select_next_item", "ai_accept" }), "fallback" },
        ["<S-Tab>"] = { LazyVim.cmp.map({ "snippet_backward", "select_prev_item" }), "fallback" },
      },
    }

    return vim.tbl_deep_extend("force", default_opts, opts)
  end,
}
