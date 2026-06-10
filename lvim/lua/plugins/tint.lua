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
        local hex = vim.o.background == "dark" and "#000000" or "#FFFFFF"
        local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
        if bg then
          hex = "#" .. require("tint.colors").get_hex(bg)
        end
        if vim.o.background == "dark" then
          transforms[1] = require("tint.transforms").tint_with_threshold(-50, hex, 125)
        else
          transforms[1] = require("tint.transforms").tint_with_threshold(100, hex, 200)
        end
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
