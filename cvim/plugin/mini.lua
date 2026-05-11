local map = vim.keymap.set

Config.add("nvim-mini/mini.nvim")

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
    custom_textobjects = {
      G = gen_ai_spec.buffer(),
      D = gen_ai_spec.diagnostic(),
      I = gen_ai_spec.indent(),
      V = gen_ai_spec.line(),
      N = gen_ai_spec.number(),
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

local ext3_blocklist = { scm = true, txt = true, yml = true }
local ext4_blocklist = { json = true, yaml = true }
require("mini.icons").setup({
  use_file_extension = function(ext, _)
    return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
  end,
})

require("config.mini.sessions").setup()
require("config.mini.files").setup()
