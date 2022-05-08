local Dashboard = {}

Dashboard.config = function()
  if not lvim.builtin.alpha.active then
    return
  end

  lvim.builtin.alpha.mode = "dashboard"
end

return Dashboard
