---@module "snacks"
---@type snacks.picker.sources.Config | {} | table<string, snacks.picker.Config | {}>
local sources = {}

sources.git_status = {
  layout = {
    preview = true,
  },
}

sources.git_diff = {
  layout = {
    preview = true,
  },
}

sources.scratch = {
  layout = {
    preview = true,
  },
}

return sources
