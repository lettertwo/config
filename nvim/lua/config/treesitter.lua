local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if not status_ok then
  return
end

local keymap = require("keymap")

keymap.operator.label("af", "a function")
keymap.operator.label("if", "inner function")
keymap.operator.label("ac", "a class")
keymap.operator.label("ic", "inner class")
keymap.operator.label(",", "previous selection")
keymap.operator.label(".", "smart selection")
keymap.operator.label(";", "container")
keymap.operator.label("i;", "inner container")

keymap.normal.label("gd", "Go to definition")

-- local _, parsers = pcall(require, "nvim-treesitter.parsers")
-- if parsers then
--   -- Associate the flowtype filetype with the typescript parser.
--   -- See autocommands.lua for more.
--   parsers.filetype_to_parsername.flowtype = "typescript"
-- end

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
    use_languagetree = true,
    additional_vim_regex_highlighting = false,
  },
  matchup = { enable = true },
  autopairs = { enable = true },
  indent = { enable = true, disable = { "python", "css" } },
  endwise = { enable = true },
  context_commentstring = { enable = true, enable_autocmd = false },
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
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
    prev_selection = ",", -- (Optional) keymap to select the previous selection
    keymaps = {
      ["."] = "textsubjects-smart",
      [";"] = "textsubjects-container-outer",
      ["i;"] = "textsubjects-container-inner",
    },
  },
  refactor = {
    highlight_current_scope = {
      enable = true,
    },
    highlight_definitions = {
      enable = true,
      clear_on_cursor_move = false,
    },
    smart_rename = {
      enable = true,
      keymaps = {
        smart_rename = "<nop>",
      },
    },
    navigation = {
      enable = true,
      keymaps = {
        goto_definition_lsp_fallback = "gd",
        goto_definition = "<nop>",
        list_definitions = "<nop>",
        list_definitions_toc = "<nop>",
        goto_next_usage = "<nop>",
        goto_previous_usage = "<nop>",
      },
    },
  },
})
