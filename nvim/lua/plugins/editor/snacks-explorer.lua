---@module "snacks"

local function grapple_file(item, picker)
  local ret = require("snacks.picker.format").file(item, picker)
  if item.tag ~= nil then
    table.insert(ret, {
      col = 0,
      virt_text = { { LazyVim.config.icons.tag, "SnacksPickerSelected" } },
      virt_text_pos = "right_align",
      hl_mode = "combine",
    })
  end
  return ret
end

return {
  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      explorer = {
        replace_netrw = false,
      },
      sources = {
        explorer = {
          format = grapple_file,
          transform = function(item)
            local grapple_ok, grapple = pcall(require, "grapple")
            if grapple_ok then
              local filepath = Snacks.picker.util.path(item)
              if filepath then
                local ok, tag = pcall(grapple.name_or_index, { path = filepath })
                if ok and tag then
                  item.tag = tag
                end
              end
            end
            return item
          end,
          actions = {
            toggle_tag = function(picker, item)
              local grapple_ok, grapple = pcall(require, "grapple")
              if grapple_ok then
                local filepath = Snacks.picker.util.path(item)
                if filepath then
                  grapple.toggle({ path = filepath })
                  require("snacks.explorer.actions").actions.explorer_update(picker)
                end
              else
                vim.notify("grapple not found", vim.log.levels.WARN)
              end
            end,
          },
          win = {
            list = {
              keys = {
                ["<C-m>"] = "toggle_tag",
              },
            },
          },
        },
      },
    },
    keys = {
      { "<leader>e", false },
      {
        "<leader>fe",
        function()
          Snacks.explorer({ cwd = LazyVim.root(), layout = { layout = { width = 0.3 } } })
        end,
        desc = "File Tree (root dir)",
      },
      {
        "<leader>fE",
        function()
          Snacks.explorer({ layout = { layout = { width = 0.3 } } })
        end,
        desc = "File Tree (cwd)",
      },
      { "<leader>E", "<leader>fE", desc = "File Tree (cwd)", remap = true },
    },
  },
}
