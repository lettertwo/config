---@module "snacks"

---@param picker snacks.Picker
local function select_current_buffer(picker)
  for i, item in ipairs(picker.list.items) do
    if item and item.flags and item.flags:find("%%") then
      picker.list:set_target(i)
      break
    end
  end
end

return {
  "folke/snacks.nvim",
  -- stylua: ignore
  keys = {
    { "<leader><space>", LazyVim.pick("switch"), desc = "Switch" },
    { "<leader>R",       LazyVim.pick("switch", { scope = "root" }),     desc = "Switch (root)" },
    { "<leader>r",       LazyVim.pick("switch", { scope = "package" }),  desc = "Switch (package)" },
  },
  ---@type snacks.Config
  opts = {
    picker = {
      sources = {
        switch = {
          multi = { "buffers", "recent", "files" },
          matcher = {
            cwd_bonus = true, -- boost cwd matches
            frecency = true, -- use frecency boosting
            sort_empty = false, -- sort even when the filter is empty
          },
          transform = "unique_file",
          on_show = select_current_buffer,
        },
      },
    },
  },
}
