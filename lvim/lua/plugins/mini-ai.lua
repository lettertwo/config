return {
  {
    "nvim-mini/mini.ai",
    opts = function(_, opts)
      local ai = require("mini.ai")
      opts = vim.tbl_deep_extend("force", opts or {}, {
        n_lines = 500,
        custom_textobjects = {
          -- taken from LazyVim.plugins.coding
          C = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }), -- class
          -- comment; nvim-treesitter/nvim-treesitter-textobjects only defines "@comment.outer".
          c = ai.gen_spec.treesitter({ a = "@comment.outer", i = "@comment.inner" }), -- comment
          ["%"] = LazyVim.mini.ai_buffer,
          -- current line; taken from MiniExtras.gen_ai_spec.line
          V = function(ai_type)
            local line_num = vim.fn.line(".")
            local line = vim.fn.getline(line_num)
            -- Ignore indentation for `i` textobject
            local from_col = ai_type == "a" and 1 or (line:match("^(%s*)"):len() + 1)
            -- Don't select `\n` past the line to operate within a line
            local to_col = line:len()

            return { from = { line = line_num, col = from_col }, to = { line = line_num, col = to_col } }
          end,
        },
      })

      return opts
    end,
    config = function(_, opts)
      require("mini.ai").setup(opts)
      LazyVim.on_load("which-key.nvim", function()
        vim.schedule(function()
          LazyVim.mini.ai_whichkey(opts)
          local wk = require("which-key")

          wk.add({
            mode = { "o", "x" },
            { "aC", desc = "class" },
            { "iC", desc = "class" },
            { "anC", desc = "class" },
            { "inC", desc = "class" },
            { "alC", desc = "class" },
            { "ilC", desc = "class" },

            { "ac", desc = "comment" },
            { "ic", desc = "comment" },
            { "anc", desc = "comment" },
            { "inc", desc = "comment" },
            { "alc", desc = "comment" },
            { "ilc", desc = "comment" },

            { "aV", desc = "line" },
            { "iV", desc = "line" },
            { "anV", desc = "line" },
            { "inV", desc = "line" },
            { "alV", desc = "line" },
            { "ilV", desc = "line" },

            { "a%", desc = "entire file" },
            { "i%", desc = "entire file" },
            { "an%", desc = "entire file" },
            { "in%", desc = "entire file" },
            { "al%", desc = "entire file" },
            { "il%", desc = "entire file" },
          })
        end)
      end)
    end,
  },
}
