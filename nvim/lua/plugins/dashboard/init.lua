local mru = require("plugins.dashboard.mru").mru
local layout = require("plugins.dashboard.layout")
local state = require("plugins.dashboard.state")
local Util = require("util")

return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    cmd = { "Alpha" },
    keys = { { "<leader>;", "<cmd>Alpha<CR>", desc = "Dashboard" } },
    config = function()
      local alpha = require("alpha")
      local button = require("alpha.themes.dashboard").button

      local lazy_button = state.button("L", " ", "Lazy", "<CMD>Lazy<CR>", nil, layout.render_immediate)
      local mason_button = state.button("M", " ", "Mason", "<CMD>Mason<CR>", nil, layout.render_immediate)

      ---@type Element[]
      local sections = {
        {
          type = "group",
          val = {
            {
              type = "text",
              val = "Recent files",
              opts = { hl = "SpecialComment", position = "center" },
            },
            { type = "padding", val = 1 },
            { type = "group", val = mru },
          },
        },
        { type = "padding", val = 2 },
        {
          type = "group",
          val = {
            {
              type = "text",
              val = "Neovim  " .. state.version,
              opts = { hl = "SpecialComment", position = "center" },
            },
            {
              type = "text",
              val = state.commit,
              opts = { hl = "Comment", position = "center" },
            },
            { type = "padding", val = 1 },
            button("l", "  Load Session", [[:lua require("persistence").load() <cr>]]),
            lazy_button,
            mason_button,
            button("C", "󰓙 Checkhealth", "<CMD>checkhealth<CR>"),
            button("S", "󰔛 Profile startup", "<CMD>Lazy profile<CR>"),
          },
        },
        { type = "padding", val = 2 },
        button("n", "󰈤  New File", "<CMD>ene!<CR>"),
        button(";", "󰅚  Close", "<CMD>Alpha<CR>"),
        button("q", "󰐥  Quit", "<CMD>qa<CR>"),
        {
          type = "group",
          val = {
            { type = "padding", val = 2 },
            {
              type = "text",
              val = function()
                local stats = require("lazy").stats()
                if stats.startuptime == 0 then
                  return ""
                end

                local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
                return "⚡ Loaded " .. stats.count .. " plugins in " .. ms .. "ms"
              end,
              opts = { hl = "SpecialComment", position = "center" },
            },
          },
        },
      }

      local group = vim.api.nvim_create_augroup("Dashboard", { clear = true })

      --- @type nil | fun():nil
      local clear_lazy_status_poll = nil

      local function ready()
        vim.api.nvim_create_autocmd("VimResized", { pattern = "*", group = group, callback = layout.render })
        vim.api.nvim_create_autocmd("User", { pattern = "LazyVimStarted", group = group, callback = layout.render })

        local lazy_checker = require("lazy.manage.checker")

        vim.api.nvim_create_autocmd("User", {
          group = group,
          once = true,
          pattern = "LazyCheck",
          callback = function(event)
            if not lazy_checker.updating and not lazy_checker.running then
              lazy_button(#lazy_checker.updated, layout.render)
            end
          end,
        })

        clear_lazy_status_poll = Util.interval(1000, function()
          if not lazy_checker.updating and not lazy_checker.running then
            lazy_button(#lazy_checker.updated, layout.render)
            if type(clear_lazy_status_poll) == "function" then
              clear_lazy_status_poll()
              clear_lazy_status_poll = nil
            end
          end
        end)

        lazy_checker.fast_check()

        vim.api.nvim_create_autocmd("User", {
          group = group,
          pattern = "LazyLoad",
          callback = function(event)
            if event.data == "mason.nvim" then
              vim.schedule(function()
                local registry_ok, registry = pcall(require, "mason-registry")
                if registry_ok then
                  local update_count = 0
                  registry.refresh(function()
                    for _, name in ipairs(registry.get_installed_package_names()) do
                      registry.get_package(name):check_new_version(function(ok)
                        if ok then
                          update_count = update_count + 1
                          mason_button(update_count, layout.render)
                        end
                      end)
                    end
                    mason_button(update_count, layout.render)
                  end)
                end
              end)
              return true -- delete the autocmd
            end
          end,
        })

        vim.api.nvim_create_autocmd("User", {
          group = group,
          once = true,
          pattern = "AlphaClosed",
          callback = function()
            vim.api.nvim_clear_autocmds({ group = group })
            if type(clear_lazy_status_poll) == "funciton" then
              clear_lazy_status_poll()
              clear_lazy_status_poll = nil
            end

            vim.api.nvim_create_autocmd("User", {
              group = group,
              once = true,
              pattern = "AlphaReady",
              callback = ready,
            })
            -- TODO: unload the alpha plugin and config?
          end,
        })
      end

      vim.api.nvim_create_autocmd("User", {
        group = group,
        once = true,
        pattern = "AlphaReady",
        callback = ready,
      })

      alpha.setup({
        opts = {
          margin = 0,
          win = nil,
          setup = layout.setup,
          redraw_on_resize = false,
        },
        layout = {
          {
            type = "group",
            val = function()
              local winwidth = vim.api.nvim_win_get_width(state.alpha_win() or 0)
              return layout.resize(winwidth, sections)
            end,
          },
        },
      })
    end,
  },
}
