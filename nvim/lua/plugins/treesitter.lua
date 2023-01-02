local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if not status_ok then
  return
end

require("treesitter-context").setup({})

local keymap = require("config.keymap")

keymap.operator.label("af", "a function")
keymap.operator.label("if", "inner function")
keymap.operator.label("ac", "a class")
keymap.operator.label("ic", "inner class")
keymap.operator.label("<CR>", "expand selection")
keymap.operator.label("<S-CR>", "shrink selection")

local _, parsers = pcall(require, "nvim-treesitter.parsers")
if parsers then
  -- Associate the flowtype filetypes with the typescript parser.
  parsers.filetype_to_parsername.flowtype = "typescript"
  parsers.filetype_to_parsername.flowtypereact = "tsx"
end

configs.setup({
  ensure_installed = {
    "bash",
    "c",
    "css",
    "dockerfile",
    "go",
    "graphql",
    "html",
    "java",
    "javascript",
    "jsdoc",
    "json",
    "json5",
    "lua",
    "make",
    "markdown",
    "python",
    "regex",
    "rust",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "yaml",
  },
  ignore_install = { "haskell" },
  highlight = {
    enable = true, -- false will disable the whole extension
    additional_vim_regex_highlighting = false,
  },
  matchup = { enable = true },
  autopairs = { enable = true },
  indent = { enable = true },
  endwise = { enable = true },
  context_commentstring = { enable = true, enable_autocmd = false },
  textobjects = {
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        ["]f"] = "@function.outer",
        ["]]"] = "@class.outer",
      },
      goto_next_end = {
        ["]F"] = "@function.outer",
        ["]["] = "@class.outer",
      },
      goto_previous_start = {
        ["[f"] = "@function.outer",
        ["[["] = "@class.outer",
      },
      goto_previous_end = {
        ["[F"] = "@function.outer",
        ["[]"] = "@class.outer",
      },
    },
    select = {
      enable = true,
      lookahead = true,
      include_surrounding_whitespace = true,
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
      },
    },
  },
  textsubjects = {
    enable = true,
    prev_selection = "<S-CR>", -- (Optional) keymap to select the previous selection
    keymaps = {
      ["<cr>"] = "textsubjects-smart",
    },
  },
  refactor = {
    highlight_definitions = {
      enable = true,
      clear_on_cursor_move = false,
    },
  },
})
