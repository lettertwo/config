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

local ext3_blocklist = { scm = true, txt = true, yml = true }
local ext4_blocklist = { json = true, yaml = true }
require("mini.icons").setup({
  use_file_extension = function(ext, _)
    return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
  end,
})

local MiniSessions = require("mini.sessions")
MiniSessions.setup({
  autoread = false,
  autowrite = false, -- managed manually below so we can gate on need_save()
  directory = vim.fs.joinpath(vim.fn.stdpath("state"), "sessions"),
  file = "", -- disable local (per-cwd file) sessions
})

local SKIP_FT = { gitcommit = true, gitrebase = true, jj = true }
local function need_save()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.bo[buf].buflisted
      and vim.bo[buf].buftype == ""
      and not SKIP_FT[vim.bo[buf].filetype]
      and vim.api.nvim_buf_get_name(buf) ~= ""
    then
      return true
    end
  end
  return false
end

Config.on("VimLeavePre", function()
  if need_save() then
    pcall(MiniSessions.write, Config.get_session_filename())
  end
end, "Autosave session")

vim.api.nvim_create_user_command("RestoreSession", function()
  MiniSessions.read(Config.get_session_filename())
end, { desc = "Restore Session" })

-- stylua: ignore start
map("n", "<leader>qs", function() MiniSessions.select("read") end, { desc = "Select Session" })
map("n", "<leader>ql", function() MiniSessions.read(Config.get_session_filename()) end, { desc = "Restore Session" })
map("n", "<leader>qd", function() MiniSessions.delete(Config.get_session_filename()) end, { desc = "Delete Session" })
map("n", "<leader>qR", "<cmd>restart lua Config.load_last_session()<cr>", { desc = "Restart" })
-- stylua: ignore end

require("config.mini.files").setup()
require("config.mini.statusline").setup()
