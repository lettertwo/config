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

sources.lsp_references = {
  layout = {
    preview = true,
  },
}

sources.lsp_definitions = {
  layout = {
    preview = true,
  },
}

sources.lsp_declarations = {
  layout = {
    preview = true,
  },
}

sources.lsp_implementations = {
  layout = {
    preview = true,
  },
}

sources.lsp_type_definitions = {
  layout = {
    preview = true,
  },
}

sources.lsp_incoming_calls = {
  layout = {
    preview = true,
  },
}

sources.lsp_outgoing_calls = {
  layout = {
    preview = true,
  },
}

return sources
