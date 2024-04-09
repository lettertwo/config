-- TODO: Implement a MERGETOOL mode that:
--  - Activates the git-conflict plugin
--  - implements special keybinds for navigating between conflicts (git-conflict does some of this already)
--  - exits with error code if conflicts are not resolved

local function nvim_as_mergetool()
  return os.getenv("GIT_MERGE_AUTOEDIT") == "no"
end

return {
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    cond = nvim_as_mergetool,
    opts = {
      default_mappings = true, -- disable buffer local mapping created by this plugin
      default_commands = true, -- disable commands created by this plugin
      disable_diagnostics = false, -- This will disable the diagnostics in a buffer whilst it is conflicted
      list_opener = "copen", -- command or function to open the conflicts list
      highlights = { -- They must have background color, otherwise the default color will be used
        incoming = "DiffAdd",
        current = "DiffText",
      },
    },
  },
}
