---@class Config.MiniCompletion
local MiniCompletionConfig = {}

function MiniCompletionConfig.setup()
  Config.add("nvim-mini/mini.nvim")

  -- Don't show 'Text' suggestions (usually noisy) and show snippets last.
  local process_items_opts = { kind_priority = { Text = -1, Snippet = 99 } }
  local process_items = function(items, base)
    return MiniCompletion.default_process_items(items, base, process_items_opts)
  end
  require("mini.completion").setup({
    -- (virtually) disable automatic completion/info/signature
    -- via very high delay time. We expect to manually invoke completion
    -- only when we want it, and info and signature are
    -- already accounted for via noice.nvim
    delay = { completion = 1e7, info = 1e7, signature = 1e7 },
    lsp_completion = {
      -- Without this config autocompletion is set up through `:h 'completefunc'`.
      -- Although not needed, setting up through `:h 'omnifunc'` is cleaner
      -- (sets up only when needed) and makes it possible to use `<C-u>`.
      source_func = "omnifunc",
      auto_setup = false,
      process_items = process_items,
      mappings = {
        -- Force two-step/fallback completions
        force_twostep = "<C-Space>",
        force_fallback = "",

        -- Scroll info/signature window down/up. When overriding, check for
        -- conflicts with built-in keys for popup menu (like `<C-u>`/`<C-o>`
        -- for 'completefunc'/'omnifunc' source function; or `<C-n>`/`<C-p>`).
        scroll_down = "<C-d>",
        scroll_up = "<C-u>",
      },
    },
  })

  Config.on("FileType", Config.filetypes.ui, function(ev)
    vim.b[ev.buf].minicompletion_disable = true
  end, "Disable completion for ui filetypes")

  -- Set 'omnifunc' for LSP completion only when needed.
  Config.on("LspAttach", function(ev)
    vim.bo[ev.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
  end, "Set 'omnifunc'")

  -- Advertise to servers that Neovim now supports certain set of completion and
  -- signature features through 'mini.completion'.
  vim.lsp.config("*", { capabilities = MiniCompletion.get_lsp_capabilities() })

  require("mini.icons").tweak_lsp_kind()

  local function is_at_trigger_char()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local char_before = line:sub(col, col)
    return char_before:match("^%s*$") == nil
  end

  -- Use `<Tab>` and `<S-Tab>` for navigation through completion list and snippet stops.
  local map_multistep = require("mini.keymap").map_multistep
  map_multistep({ "i", "s" }, "<Tab>", {
    "vimsnippet_next",
    {
      condition = function()
        return vim.fn.pumvisible() == 0 and is_at_trigger_char()
      end,
      action = function()
        MiniCompletion.complete_twostage(true, true)
      end,
    },
    "pmenu_next",
  })
  map_multistep({ "i", "s" }, "<S-Tab>", { "vimsnippet_prev", "pmenu_prev" })
  map_multistep("i", "<CR>", { "pmenu_accept", "minipairs_cr" })
  map_multistep("i", "<BS>", { "minipairs_bs" })
end

return MiniCompletionConfig
