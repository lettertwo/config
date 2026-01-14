return {
  {
    "nvim-mini/mini.surround",
    opts = {
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
    },
    keys = {
      -- Convenience for quickly surrounding with () or {}
      { "(", "gs(", desc = "Add surrounding () to selection", remap = true, mode = "x" },
      { ")", "gs)", desc = "Add surrounding () to selection", remap = true, mode = "x" },
      { "{", "gs{", desc = "Add surrounding {} to selection", remap = true, mode = "x" },
      { "}", "gs}", desc = "Add surrounding {} to selection", remap = true, mode = "x" },
    },
  },
  {
    "lettertwo/occurrence.nvim",
    optional = true,
    opts = {
      operators = {
        ["gs"] = {
          desc = "Surround marked occurrences",
          before = function(marks, ctx)
            local ok, mini_surround = pcall(require, "mini.surround")
            if not ok then
              vim.notify("mini.surround not found", vim.log.levels.WARN)
              return false
            end

            -- HACK: Access mini.surround's internals via debug
            local H = nil
            local info = debug.getinfo(mini_surround.add, "u")
            for i = 1, info.nups do
              local name, value = debug.getupvalue(mini_surround.add, i)
              if name == "H" and type(value) == "table" then
                H = value
                break
              end
            end

            if not H or not H.get_surround_spec then
              vim.notify("Could not access mini.surround internals", vim.log.levels.WARN)
              return false
            end

            ---@diagnostic disable-next-line: redefined-local
            local ok, surr_info = pcall(H.get_surround_spec, "output")

            if not ok or not surr_info or not surr_info.left or not surr_info.right then
              vim.notify("Invalid surround specification", vim.log.levels.WARN)
              return false
            end

            -- Store in context for operator to use
            ctx.surr_info = surr_info
            ctx.respect_selection_type = mini_surround.config.respect_selection_type
          end,
          operator = function(current, ctx)
            if not ctx.surr_info then
              return false
            end
            ctx.register = nil -- Don't yank replaced text to register
            if ctx.respect_selection_type then
              return vim.tbl_map(function(line)
                return ctx.surr_info.left .. line .. ctx.surr_info.right
              end, current.text)
            else
              return ctx.surr_info.left .. table.concat(current.text, "\n") .. ctx.surr_info.right
            end
          end,
        },
      },
    },
  },
}
