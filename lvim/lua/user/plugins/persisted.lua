local Persisted = {}

function Persisted.config()
  require("persisted").setup({
    use_git_branch = true,
    allowed_dirs = {
      "~/.local/share",
      "~/.config",
      "~/Code",
    },
  })

  local _, telescope = pcall(require, "telescope")
  if telescope then
    telescope.load_extension("persisted")
  end

  lvim.builtin.which_key.mappings["S"] = { "<cmd>Telescope persisted<cr>", "Sessions" }
end

return Persisted
