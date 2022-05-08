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
  require("telescope").load_extension("persisted")

  lvim.builtin.which_key.mappings["S"] = { "<cmd>Telescope persisted<cr>", "Sessions" }
end

return Persisted
