local Notify = {}

function Notify.config()
  if not lvim.builtin.notify.active then
    return
  end

  local _, telescope = pcall(require, "telescope")
  if telescope then
    telescope.load_extension("notify")
    lvim.builtin.which_key.mappings["n"] = { "<cmd>Telescope notify<CR>", "Notifications" }
  else
    lvim.builtin.which_key.mappings["n"] = { "<cmd>Notifications<CR>", "Notifications" }
  end
end

return Notify
