local map = vim.keymap.set

Config.once("BufReadPost", function()
  require("mini.trailspace").setup()
  require("mini.bracketed").setup()
  require("mini.pairs").setup({ modes = { command = true } })
  require("mini.misc").setup_restore_cursor()
  require("mini.cmdline").setup()

  require("mini.operators").setup({
    evaluate = { prefix = "g=" },
    exchange = { prefix = "gX" },
    multiply = { prefix = "gm" },
    replace = { prefix = "gR" },
    sort = { prefix = "gS" },
  })

  require("mini.splitjoin").setup({
    mappings = {
      toggle = "J",
      split = "",
      join = "",
    },
  })

  -- on MacOS, <A-j> emits "∆", <A-k> emits "˚", <A-h> emits "˙", <A-l> emits "¬"
  require("mini.move").setup({
    mappings = {
      left = "˙",
      right = "¬",
      down = "∆",
      up = "˚",
      line_left = "˙",
      line_right = "¬",
      line_down = "∆",
      line_up = "˚",
    },
  })

  require("mini.align").setup({
    -- Module mappings. Use `''` (empty string) to disable one.
    mappings = {
      start = "",
      start_with_preview = "ga",
    },
    modifiers = {
      ["1"] = function(steps)
        table.insert(steps.pre_justify, require("mini.align").gen_step.filter("n == 1"))
      end,
    },
  })

  local ai = require("mini.ai")
  local gen_ai_spec = require("mini.extra").gen_ai_spec
  ai.setup({
    n_lines = 500,
    search_method = "cover",
    mappings = {
      around = "a",
      inside = "i",
      around_next = "",
      inside_next = "",
      around_last = "",
      inside_last = "",
      goto_left = "[a",
      goto_right = "]a",
    },
    custom_textobjects = {
      G = gen_ai_spec.buffer(),
      x = gen_ai_spec.diagnostic(),
      i = gen_ai_spec.indent(),
      V = gen_ai_spec.line(),
      d = gen_ai_spec.number(),
      b = ai.gen_spec.treesitter({ -- code block
        a = { "@block.outer", "@conditional.outer", "@loop.outer" },
        i = { "@block.inner", "@conditional.inner", "@loop.inner" },
      }),
      f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }), -- function
      t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
      e = { -- Word with case
        { "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
        "^().*()$",
      },
      u = ai.gen_spec.function_call(), -- u for "Usage"
      U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }), -- without dot in function name

      C = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }), -- class
      -- comment; nvim-treesitter/nvim-treesitter-textobjects only defines "@comment.outer".
      c = ai.gen_spec.treesitter({ a = "@comment.outer", i = "@comment.inner" }), -- comment
    },
  })

  vim.schedule(function()
    local wk_ok, wk = pcall(require, "which-key")
    if wk ~= nil and wk_ok then
      local objects = {
        { " ", desc = "whitespace" },
        { '"', desc = '" string' },
        { "'", desc = "' string" },
        { "(", desc = "() block" },
        { ")", desc = "( ) block" },
        { "<", desc = "<> block" },
        { ">", desc = "< > block" },
        { "?", desc = "prompt" },
        { "[", desc = "[] block" },
        { "]", desc = "[ ] block" },
        { "_", desc = "underscore" },
        { "`", desc = "` string" },
        { "a", desc = "argument" },
        { "q", desc = "quote `\"'" },
        { "{", desc = "{} block" },
        { "}", desc = "{ } block" },

        { "G", desc = "entire file" },
        { "x", desc = "diagnostic" },
        { "i", desc = "indent" },
        { "V", desc = "line" },
        { "d", desc = "digit(s)" },
        { "b", desc = "block, conditional, loop" },
        { "f", desc = "function" },
        { "t", desc = "tag" },
        { "e", desc = "CamelCase / snake_case" },
        { "u", desc = "method.call(usage)" },
        { "U", desc = "call(usage)" },
        { "C", desc = "class" },
        { "c", desc = "comment" },
      }

      local ox = {
        mode = { "o", "x" },
        { "a", group = "around" },
        { "i", group = "inner" },
      }

      local nox = {
        mode = { "n", "o", "x" },
        { "[a", group = "around" },
        { "]a", group = "around" },
      }

      for _, obj in ipairs(objects) do
        ox[#ox + 1] = { "a" .. obj[1], desc = obj.desc }
        ox[#ox + 1] = { "i" .. obj[1], desc = obj.desc }
        nox[#nox + 1] = { "]a" .. obj[1], desc = obj.desc }
        nox[#nox + 1] = { "[a" .. obj[1], desc = obj.desc }
      end

      wk.add({ ox, nox }, { notify = false })
    end
  end)

  require("mini.surround").setup({
    custom_surroundings = {
      -- Invert the balanced bracket behaviors.
      -- Open inserts without space, close inserts with space.
      ["("] = { output = { left = "(", right = ")" } },
      [")"] = { output = { left = "( ", right = " )" } },
      ["{"] = { output = { left = "{", right = "}" } },
      ["}"] = { output = { left = "{ ", right = " }" } },
      ["["] = { output = { left = "[", right = "]" } },
      ["]"] = { output = { left = "[ ", right = " ]" } },
      ["<"] = { output = { left = "<", right = ">" } },
      [">"] = { output = { left = "< ", right = " >" } },
    },
    mappings = {
      add = "gs", -- Add surrounding in Normal and Visual modes
      delete = "ds", -- Delete surrounding
      replace = "cs", -- Replace surrounding

      find = "", -- Find surrounding (to the right)
      find_left = "", -- Find surrounding (to the left)
      highlight = "", -- Highlight surrounding
      suffix_last = "", -- Suffix to search with "prev" method
      suffix_next = "", -- Suffix to search with "next" method
      update_n_lines = "", -- Update `n_lines`
    },
    n_lines = 500,
    search_method = "cover_or_next",
    respect_selection_type = true,
  })

  -- Convenience for quickly surrounding with () or {}
  map("x", "(", "gs(", { desc = "Add surrounding () to selection", remap = true })
  map("x", ")", "gs)", { desc = "Add surrounding () to selection", remap = true })
  map("x", "{", "gs{", { desc = "Add surrounding {} to selection", remap = true })
  map("x", "}", "gs}", { desc = "Add surrounding {} to selection", remap = true })
end)

require("config.mini.files").setup()

-- commenting
map("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Below" })
map("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Above" })

-- change the word under the cursor
map("n", "<C-CR>", "ciw", { desc = "Change word under cursor" })
map("i", "<C-CR>", "<C-o>diw", { desc = "Change next word under cursor" })

-- undo break-points on common punctuation
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

Config.add("nvim-treesitter/nvim-treesitter-textobjects")

Config.on("FileType", function(args)
  if vim.list_contains(Config.filetypes.ui, args.match) then
    return
  end
  local lang = vim.treesitter.language.get_lang(args.match)
  if lang then
    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end)

-- highlights under cursor
map("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })
map("n", "<leader>uI", function()
  vim.treesitter.inspect_tree()
  vim.api.nvim_input("I")
end, { desc = "Inspect Tree" })

-- incremental treesitter selection (+ lsp fallback)
map({ "n", "o", "x" }, "<S-CR>", function()
  if vim.treesitter.get_parser(nil, nil, { error = false }) and pcall(require, "vim.treesitter._select") then
    require("vim.treesitter._select").select_parent(vim.v.count1)
  else
    vim.lsp.buf.selection_range(vim.v.count1)
  end
end, { desc = "Increment Selection" })

map({ "o", "x" }, "<BS>", function()
  if vim.treesitter.get_parser(nil, nil, { error = false }) and pcall(require, "vim.treesitter._select") then
    require("vim.treesitter._select").select_child(vim.v.count1)
  else
    vim.lsp.buf.selection_range(-vim.v.count1)
  end
end, { desc = "Decrement Selection" })
