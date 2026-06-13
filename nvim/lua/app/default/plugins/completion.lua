-- Computes how many characters of the inline completion item
-- have already been typed or accepted, so that we can skip them
-- when accepting the item partially.
---@param item vim.lsp.inline_completion.Item
---@param bufnr integer
---@return integer number of characters to skip in the typed prefix
local function skip_typed_prefix(item, bufnr)
  local insert_text = item.insert_text
  if type(insert_text) ~= "string" or not item.range then
    return 0
  end
  local start_row, start_col = item.range:to_extmark()
  local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
  local first_line = insert_text:match("^[^\n]*")
  local rest = line:sub(start_col + 1)
  local i = 1
  while i <= #rest and i <= #first_line and rest:sub(i, i) == first_line:sub(i, i) do
    i = i + 1
  end
  return i - 1
end

-- Returns the next word from the given suffix `string`.
---@param suffix string
---@return string
local function next_word(suffix)
  return suffix:match("^[ \t]*[^%s]+") or suffix:match("^[ \t]+") or ""
end

-- Returns the next line from the given suffix `string`,
-- including the newline character if present.
-- When the suffix starts with a newline,
-- the entire next line is returned.
---@param suffix string
---@return string
local function next_line(suffix)
  local nl = suffix:find("\n", 1, true)
  if not nl then
    return suffix
  end
  -- When the suffix starts with \n the cursor is at end-of-line; take through
  -- the following line's end so the whole next line is accepted, not just a \n.
  if nl == 1 then
    local nl2 = suffix:find("\n", 2, true)
    return nl2 and suffix:sub(1, nl2) or suffix
  end
  return suffix:sub(1, nl)
end

-- Get the active inline completor for the given buffer, if any.
---@param bufnr integer
---@return vim.lsp.inline_completion.Completor?
local function get_inline_completor(bufnr)
  local ok, Capability = pcall(require, "vim.lsp._capability")
  if not ok then
    return nil
  end
  local Completor = Capability.all and Capability.all["inline_completion"]
  if Completor and Completor.active then
    return Completor.active[bufnr] --[[ @as vim.lsp.inline_completion.Completor? ]]
  end
end

-- Abort the active inline completion for the given buffer, if any.
---@param bufnr integer
---@return boolean true if completion was hidden
local function hide_inline_completion(bufnr)
  local completor = get_inline_completor(bufnr)
  if completor and completor.current then
    ---@diagnostic disable-next-line: invisible
    completor:abort()
    return true
  end
  return false
end

-- Check if the character before the cursor is a trigger character for completion.
---@return boolean true if the character before the cursor is a trigger character for completion
local function is_at_trigger_char()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local char_before = line:sub(col, col)
  return char_before:match("^%s*$") == nil
end

-- mini.multistep action to accept the entire inline completion item.
local inline_accept = {
  condition = function()
    local completor = get_inline_completor(vim.api.nvim_get_current_buf())
    return vim.fn.pumvisible() == 0 and completor ~= nil and completor.current ~= nil
  end,
  action = function()
    vim.lsp.inline_completion.get({ bufnr = vim.api.nvim_get_current_buf() })
  end,
}

-- mini.multistep action to accept only part of the inline completion item.
-- The `take` function determines how much of the item to accept based on the
-- suffix of the item that has not yet been accepted. For example, `take` could be
-- a function that takes the next word or the next line from the suffix. This allows
-- for more fine-grained control over accepting inline completions, such as accepting
-- one word at a time or accepting up to the next newline.
---@param take fun(suffix: string): string
---@return { condition: fun(): boolean, action: fun() }
local function partial_accept(take)
  ---@type fun(item: vim.lsp.inline_completion.Item): vim.lsp.inline_completion.Item
  local function on_accept(item)
    local insert_text = item.insert_text
    if type(insert_text) ~= "string" then
      return item
    end
    local bufnr = vim.api.nvim_get_current_buf()
    local skip = skip_typed_prefix(item, bufnr)
    local prefix = insert_text:sub(1, skip)
    local suffix = insert_text:sub(skip + 1)
    local accepted = take(suffix)
    local remaining = suffix:sub(#accepted + 1)
    -- Set the remaining text as the new current item before accept() fires so
    -- the TextChangedI → show() call that happens during insertion renders it
    -- immediately, preventing any visible virt-text flicker.
    if remaining ~= "" then
      local completor = get_inline_completor(bufnr)
      if completor then
        completor.current = { _index = item._index, client_id = item.client_id, insert_text = remaining, range = nil }
      end
    end
    item.insert_text = prefix .. accepted
    return item
  end

  return {
    condition = function()
      local completor = get_inline_completor(vim.api.nvim_get_current_buf())
      return vim.fn.pumvisible() == 0 and completor ~= nil and completor.current ~= nil
    end,
    action = function()
      vim.lsp.inline_completion.get({ bufnr = vim.api.nvim_get_current_buf(), on_accept = on_accept })
    end,
  }
end

-- mini.multistep action to hide inline completion if visible.
local inline_hide = {
  condition = function()
    local completor = get_inline_completor(vim.api.nvim_get_current_buf())
    return completor ~= nil and completor.current ~= nil
  end,
  action = function()
    hide_inline_completion(vim.api.nvim_get_current_buf())
  end,
}

-- mini.multistep action to show popup menu if not visible and at a trigger character.
local pmenu_show = {
  condition = function()
    return vim.fn.pumvisible() == 0 and is_at_trigger_char()
  end,
  action = function()
    MiniCompletion.complete_twostage(true, true)
  end,
}

Config.once("BufReadPost", function()
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

  Config.on("LspAttach", function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end
    if client:supports_method("textDocument/completion") then
      -- Set 'omnifunc' for LSP completion only when needed.
      vim.bo[ev.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
    end
    if client:supports_method("textDocument/inlineCompletion") then
      vim.lsp.inline_completion.enable(true, { bufnr = ev.buf })
    end
  end, "Completion enable")

  -- Advertise to servers that Neovim now supports certain set of completion and
  -- signature features through 'mini.completion'.
  vim.lsp.config("*", { capabilities = MiniCompletion.get_lsp_capabilities() })

  -- Decorate completion items with icons and better labels.
  require("mini.icons").tweak_lsp_kind()

  local map_multistep = require("mini.keymap").map_multistep
  map_multistep({ "i", "s" }, "<Tab>", { "vimsnippet_next", inline_accept, pmenu_show, "pmenu_next" })
  map_multistep({ "i", "s" }, "<right>", { "vimsnippet_next", "pmenu_accept", partial_accept(next_word) })
  map_multistep({ "i", "s" }, "<S-Tab>", { "vimsnippet_prev", "pmenu_prev" })

  map_multistep("i", "<c-j>", { "pmenu_next" })
  map_multistep("i", "<down>", { "pmenu_next", partial_accept(next_line) })
  map_multistep("i", "<c-k>", { "pmenu_prev" })
  map_multistep("i", "<up>", { "pmenu_prev" })

  map_multistep("i", "<left>", { inline_hide })
  map_multistep("i", "<c-c>", { inline_hide })

  map_multistep("i", "<CR>", { "pmenu_accept" })
end)
