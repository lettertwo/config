return {
  -- Fade inactive windows while preserving syntax highlights.
  {
    "levouh/tint.nvim",
    event = "VeryLazy",
    opts = function()
      local transforms = {
        require("tint.transforms").tint(-45),
        require("tint.transforms").saturate(0.5),
      }

      local function update_transforms()
        local hex = "#000000"
        local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
        if bg then
          hex = "#" .. require("tint.colors").get_hex(bg)
        else
        end
        transforms[1] = require("tint.transforms").tint_with_threshold(-50, hex, 125)
      end

      vim.api.nvim_create_autocmd({ "ColorScheme" }, {
        callback = update_transforms,
        group = vim.api.nvim_create_augroup("tint-color-scheme-change", { clear = true }),
      })

      update_transforms()

      return { transforms = transforms }
    end,
  },
}
