return {
  {
    "echasnovski/mini.surround",
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
      n_lines = 100,
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
}
