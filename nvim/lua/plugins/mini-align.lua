return {
  {
    "nvim-mini/mini.align",
    opts = {
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
    },
  },
}
