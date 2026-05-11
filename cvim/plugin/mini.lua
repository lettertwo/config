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

  require("config.mini.ai").setup()

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
