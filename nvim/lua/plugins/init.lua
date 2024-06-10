return {
  -- A common dependency in lua plugins. Also useful for testing plugins.
  { "nvim-lua/plenary.nvim" },

  -- makes some plugins dot-repeatable like leap
  { "tpope/vim-repeat", event = "VeryLazy" },

  -- measure startuptime
  {
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    config = true,
    init = function()
      vim.g.startuptime_tries = 10
    end,
  },

  -- profiler
  {
    "stevearc/profile.nvim",
    init = function()
      local should_profile = os.getenv("NVIM_PROFILE")

      if should_profile then
        require("profile").instrument_autocmds()
        if should_profile:lower():match("^start") then
          require("profile").start("*")
        else
          require("profile").instrument("*")
        end
      end

      local function toggle_profile()
        local prof = require("profile")
        if prof.is_recording() then
          prof.stop()
          vim.ui.input(
            { prompt = "Save profile to:", completion = "file", default = "profile.json" },
            function(filename)
              if filename then
                prof.export(filename)
                vim.notify(string.format("Wrote %s", filename))
              end
            end
          )
        else
          prof.start("*")
        end
      end

      -- local function toggle_profile()
      --   if vim.v.profiling == 1 then
      --     vim.cmd([[ profile pause | profile dump | noautocmd qall! ]])
      --   else
      --     vim.cmd([[ profile start profile.log | profile func * | profile file * ]])
      --   end
      -- end

      vim.keymap.set("", "<C-p>", toggle_profile, { desc = "Toggle profile" })
    end,
  },
}
